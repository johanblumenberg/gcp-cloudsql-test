package com.example.demo

import java.time.Duration

abstract class MultiThreadRunner(threads: IntRange) {
    constructor(numThreads: Int) : this(1..numThreads)

    private val threads: List<Thread> = threads.map { i ->
        object : Thread() {
            override fun run() {
                do {
                    try {
                        runSingle(i)
                    } catch (e: Throwable) {
                        ex = e
                        done = true
                    }
                } while (!done)
            }
        }
    }
    var ex: Throwable? = null

    @Volatile
    var done = false

    open fun runSingle() { }
    open fun runSingle(i: Int) = runSingle()

    fun start() {
        threads.forEach { it.start() }
    }

    fun stop() {
        done = true
        threads.forEach { it.join() }

        val e = ex
        if (e != null) {
            throw e
        }
    }

    fun runFor(duration: Duration) {
        start()
        Thread.sleep(duration.toMillis())
        stop()
    }

    fun runOnce() {
        done = true

        threads.forEach { it.start() }
        threads.forEach { it.join() }

        val e = ex
        if (e != null) {
            throw e
        }
    }
}
