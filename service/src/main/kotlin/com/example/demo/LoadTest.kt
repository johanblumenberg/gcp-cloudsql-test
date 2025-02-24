package com.example.demo

import mu.KotlinLogging
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Duration
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import javax.sql.DataSource
import kotlin.math.max

val log = KotlinLogging.logger {}

val N = 10

@RestController
class LoadTest(
    val dataSource: DataSource,
) {
    @GetMapping("/test")
    fun load(): String {
        val count = AtomicInteger(0)
        val maxAcquire = AtomicLong(0)
        val maxRelease = AtomicLong(0)
        val maxQuery = AtomicLong(0)

        val threads = object : MultiThreadRunner(N) {
            override fun runSingle(i: Int) {
                val t0 = System.nanoTime()
                val c = dataSource.connection
                val t1 = System.nanoTime()
                val d = Duration.ofNanos(t1 - t0).toMillis()

                maxAcquire.accumulateAndGet(d) { a, b -> max(a, b) }

                try {
                    val t0 = System.nanoTime()
                    c.createStatement().execute("SELECT null")
                    val t1 = System.nanoTime()
                    val d = Duration.ofNanos(t1 - t0).toMillis()

                    count.incrementAndGet()
                    maxQuery.accumulateAndGet(d) { a, b -> max(a, b) }
                } finally {
                    val t0 = System.nanoTime()
                    c.close()
                    val t1 = System.nanoTime()
                    val d = Duration.ofNanos(t1 - t0).toMillis()

                    maxRelease.accumulateAndGet(d) { a, b -> max(a, b) }
                }

                Thread.yield()
            }
        }

        try {
            threads.runFor(Duration.ofSeconds(10))

            return "Success count: ${count.get()} [acquire:${maxAcquire.get()},release:${maxRelease.get()},query:${maxQuery.get()}]"
                .also { log.info(it) }
        } catch (e: Exception) {
            return "Failure count: ${count.get()} [acquire:${maxAcquire.get()},release:${maxRelease.get()},query:${maxQuery.get()}] ${e.message}"
                .also { log.info(it) }
        }
    }
}
