package io.joynr.messaging;

/*
 * #%L
 * %%
 * Copyright (C) 2011 - 2015 BMW Car IT GmbH
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */

import io.joynr.exceptions.JoynrSendBufferFullException;
import io.joynr.exceptions.JoynrShutdownException;
import io.joynr.messaging.http.HttpMessageSender;
import io.joynr.messaging.http.operation.FailureAction;

import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;
import com.google.inject.Inject;
import com.google.inject.name.Named;

/**
 * The MessageScheduler queues message post requests in a single threaded executor. The executor is blocked until the
 * connection is established, from there on the request is async. If there are already too much connections open, the
 * executor is blocked until one of the connections is closed. Resend attempts are scheduled by a cached thread pool
 * executor.
 */
@edu.umd.cs.findbugs.annotations.SuppressWarnings(value = "JLM_JSR166_UTILCONCURRENT_MONITORENTER", justification = "ensure that no new messages are scheduled when scheduler is shuting down")
public class MessageScheduler {
    private static final int DELAY_RECEIVER_NOT_STARTED_MS = 100;
    private static final long TERMINATION_TIMEOUT = 5000;
    private static final long SCHEDULER_KEEP_ALIVE_TIME = 100;
    private final ScheduledThreadPoolExecutor scheduler;
    private static final Logger logger = LoggerFactory.getLogger(MessageScheduler.class);
    private final HttpMessageSender httpMessageSender;

    @Inject
    public MessageScheduler(@Named(ConfigurableMessagingSettings.PROPERTY_MESSAGING_MAXIMUM_PARALLEL_SENDS) int maximumParallelSends,
                            HttpMessageSender httpMessageSender) {
        this.httpMessageSender = httpMessageSender;

        ThreadFactory schedulerNamedThreadFactory = new ThreadFactoryBuilder().setNameFormat("joynr.MessageScheduler-scheduler-%d")
                                                                              .build();
        scheduler = new ScheduledThreadPoolExecutor(maximumParallelSends, schedulerNamedThreadFactory);
        scheduler.setKeepAliveTime(SCHEDULER_KEEP_ALIVE_TIME, TimeUnit.SECONDS);
        scheduler.allowCoreThreadTimeOut(true);
    }

    public synchronized void scheduleMessage(final MessageContainer messageContainer,
                                             long delay_ms,
                                             final FailureAction failureAction,
                                             final MessageReceiver messageReceiver) {
        logger.trace("scheduleMessage messageId: {} channelId {}",
                     messageContainer.getMessageId(),
                     messageContainer.getChannelId());
        // check if messageReceiver is ready to receive replies otherwise delay request by at least 100 ms
        if (!messageReceiver.isChannelCreated()) {
            delay_ms = delay_ms > DELAY_RECEIVER_NOT_STARTED_MS ? delay_ms : DELAY_RECEIVER_NOT_STARTED_MS;
        }

        synchronized (scheduler) {
            if (scheduler.isShutdown()) {
                JoynrShutdownException joynrShutdownEx = new JoynrShutdownException("MessageScheduler is shutting down already. Unable to send message [messageId: "
                        + messageContainer.getMessageId() + "].");
                failureAction.execute(joynrShutdownEx);
                throw joynrShutdownEx;
            }

            try {
                scheduler.schedule(new Runnable() {
                    @Override
                    public void run() {
                        if (!messageReceiver.isChannelCreated()) {
                            scheduleMessage(messageContainer,
                                            DELAY_RECEIVER_NOT_STARTED_MS,
                                            failureAction,
                                            messageReceiver);
                            logger.debug("Creation of Channel for channelId {} is still ongoing. Sending messages now could lead to lost replies - delaying sending messageId {}",
                                         messageReceiver.getChannelId(),
                                         messageContainer.getMessageId());
                            return;
                        }

                        httpMessageSender.sendMessage(messageContainer, failureAction);
                    }
                },
                                   delay_ms,
                                   TimeUnit.MILLISECONDS);
            } catch (RejectedExecutionException e) {
                logger.error("Execution rejected while scheduling SendSerializedMessageRequest ", e);
                throw new JoynrSendBufferFullException(e);
            }
        }
    }

    /**
     * Stops the scheduler thread pool and the execution thread.
     * 
     * @throws InterruptedException
     */
    public synchronized void shutdown() throws InterruptedException {
        synchronized (scheduler) {
            scheduler.shutdown();
        }

        // TODO serialize messages that could not be resent because of shutdown? Or somehow notify sender?
        // List<Runnable> awaitingScheduling = scheduler.shutdownNow();
        // List<Runnable> awaitingResend = executionQueue.shutdownNow();
        scheduler.awaitTermination(TERMINATION_TIMEOUT, TimeUnit.MILLISECONDS);
    }

}
