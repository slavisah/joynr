package io.joynr.generator.cpp.filter
/*
 * !!!
 *
 * Copyright (C) 2011 - 2014 BMW Car IT GmbH
 *
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
 */

import com.google.inject.Inject
import java.io.File
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FModel
import io.joynr.generator.cpp.util.JoynrCppGeneratorExtensions

class FilterGenerator {

	@Inject
	extension JoynrCppGeneratorExtensions

	@Inject
	FilterParameterTemplate filterParameterTemplate;

	def doGenerate(FModel model,
		IFileSystemAccess sourceFileSystem,
		IFileSystemAccess headerFileSystem,
		String sourceContainerPath,
		String headerContainerPath
	) {

        for(fInterface: model.interfaces){
        	val headerPath = headerContainerPath + getPackagePathWithJoynrPrefix(fInterface, File::separator) + File::separator 
			var serviceName = fInterface.joynrName

			for (broadcast : fInterface.broadcasts) {
				if (broadcast.selective != null){
					val filterParameterLocation = headerPath + serviceName.toFirstUpper + broadcast.name.toFirstUpper + "BroadcastFilterParameters.h"
					headerFileSystem.generateFile(
						filterParameterLocation,
						filterParameterTemplate.generate(fInterface, broadcast).toString
					);
				}
			}
        }

	}
}
