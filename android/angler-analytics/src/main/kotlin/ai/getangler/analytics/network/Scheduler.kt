package ai.getangler.analytics.network

import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

internal interface Scheduler {
    fun schedule(delayMillis: Long, work: () -> Unit)
}

internal class ExecutorScheduler(private val executor: ScheduledExecutorService) : Scheduler {
    override fun schedule(delayMillis: Long, work: () -> Unit) {
        executor.schedule({ work() }, delayMillis, TimeUnit.MILLISECONDS)
    }
}
