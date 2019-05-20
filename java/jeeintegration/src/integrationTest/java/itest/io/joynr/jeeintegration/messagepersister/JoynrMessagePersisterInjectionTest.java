/*
 * #%L
 * %%
 * Copyright (C) 2018 BMW Car IT GmbH
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
package itest.io.joynr.jeeintegration.messagepersister;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.io.File;

import javax.inject.Inject;

import org.jboss.arquillian.container.test.api.Deployment;
import org.jboss.arquillian.junit.Arquillian;
import org.jboss.arquillian.test.spi.TestResult;
import org.jboss.shrinkwrap.api.Archive;
import org.jboss.shrinkwrap.api.ShrinkWrap;
import org.jboss.shrinkwrap.api.spec.JavaArchive;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.Timeout;
import org.junit.runner.RunWith;

import io.joynr.jeeintegration.api.JoynrMessagePersister;
import io.joynr.messaging.persistence.MessagePersister;

/**
 * Integration tests for the {@link JoynrMessagePersister}.
 */
@RunWith(Arquillian.class)
public class JoynrMessagePersisterInjectionTest {
    @Rule
    public Timeout globalTimeout = Timeout.seconds(60);

    @Deployment
    public static Archive<?> getDeployment() {
        return ShrinkWrap.create(JavaArchive.class)
                         .addClasses(JoynrMessagePersister.class, TestResult.class, TestMessagePersisterProducer.class)
                         .addAsManifestResource(new File("src/main/resources/META-INF/beans.xml"))
                         .addAsManifestResource(new File("src/main/resources/META-INF/services/javax.enterprise.inject.spi.Extension"));
    }

    @Inject
    private @JoynrMessagePersister MessagePersister messagePersister;

    @Test
    public void testMessagePersisterRegistered() {
        assertNotNull(messagePersister);
        assertTrue(messagePersister instanceof TestMessagePersister);
    }
}
