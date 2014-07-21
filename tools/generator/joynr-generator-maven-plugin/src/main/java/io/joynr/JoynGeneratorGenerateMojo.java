package io.joynr;

/*
 * #%L
 * %%
 * Copyright (C) 2011 - 2014 BMW Car IT GmbH
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

import io.joynr.generator.GeneratorTask;

import java.io.IOException;

import org.apache.maven.plugin.MojoExecutionException;

/**
 * Goal which generates the joynr interfaces and implementations.
 *
 * @goal generate
 * 
 * @phase process-sources
 */
public class JoynGeneratorGenerateMojo extends AbstractJoynGeneratorMojo {
    public void execute() throws MojoExecutionException {
        int executionHashCode = getParameterHashCode();
        String generationDonePropertyName = "generation.done.id[" + executionHashCode + "]";
        String generationAlreadyDone = project.getProperties().getProperty(generationDonePropertyName);
        if (new Boolean(generationAlreadyDone)) {
            getLog().info("----------------------------------------------------------------------");
            getLog().info("JOYNR GENERATOR for parameter hash \"" + executionHashCode + "\" already executed.");
            getLog().info("Sources are up-to-date, skipping code generation...");
            getLog().info("----------------------------------------------------------------------");
            return;
        }

        super.execute();
    }

    @Override
    protected void invokeGenerator(GeneratorTask task) throws IOException, ClassNotFoundException,
                                                      InstantiationException, IllegalAccessException {
        task.generate(getLog());
    }
}
