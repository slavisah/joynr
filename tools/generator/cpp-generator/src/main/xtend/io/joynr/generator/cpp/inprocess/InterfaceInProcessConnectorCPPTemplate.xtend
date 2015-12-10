package io.joynr.generator.cpp.inprocess
/*
 * !!!
 *
 * Copyright (C) 2011 - 2015 BMW Car IT GmbH
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
import io.joynr.generator.cpp.util.CppStdTypeUtil
import io.joynr.generator.cpp.util.JoynrCppGeneratorExtensions
import io.joynr.generator.cpp.util.TemplateBase
import io.joynr.generator.templates.InterfaceTemplate
import io.joynr.generator.templates.util.AttributeUtil
import io.joynr.generator.templates.util.BroadcastUtil
import io.joynr.generator.templates.util.InterfaceUtil
import io.joynr.generator.templates.util.MethodUtil
import io.joynr.generator.templates.util.NamingUtil
import org.franca.core.franca.FInterface
import org.franca.core.franca.FType

class InterfaceInProcessConnectorCPPTemplate implements InterfaceTemplate{

	@Inject private extension TemplateBase
	@Inject private extension CppStdTypeUtil cppStdTypeUtil
	@Inject private extension NamingUtil
	@Inject private extension AttributeUtil
	@Inject private extension MethodUtil
	@Inject private extension BroadcastUtil
	@Inject private extension InterfaceUtil
	@Inject private extension JoynrCppGeneratorExtensions

	override  generate(FInterface serviceInterface)
'''
«var interfaceName = serviceInterface.joynrName»
«warning()»
#include <functional>

#include "«getPackagePathWithJoynrPrefix(serviceInterface, "/")»/«interfaceName»InProcessConnector.h"
#include "«getPackagePathWithJoynrPrefix(serviceInterface, "/")»/«interfaceName»RequestCaller.h"
«FOR datatype: getAllComplexTypes(serviceInterface)»
«IF datatype instanceof FType»
	«IF isCompound(datatype)»
		#include "«getIncludeOf(datatype)»"
	«ENDIF»
«ENDIF»
«ENDFOR»

#include "joynr/InProcessAddress.h"
#include "joynr/ISubscriptionManager.h"
#include "joynr/PublicationManager.h"
#include "joynr/SubscriptionCallback.h"
#include "joynr/BroadcastSubscriptionRequest.h"
#include "joynr/Util.h"
#include "joynr/Future.h"
#include "joynr/TypeUtil.h"
#include "joynr/RequestStatus.h"
#include "joynr/RequestStatusCode.h"
#include "joynr/SubscriptionUtil.h"

«getNamespaceStarter(serviceInterface)»

using namespace joynr::joynr_logging;
Logger* «interfaceName»InProcessConnector::logger = Logging::getInstance()->getLogger("MSG", "«interfaceName»InProcessConnector");

«interfaceName»InProcessConnector::«interfaceName»InProcessConnector(
			joynr::ISubscriptionManager* subscriptionManager,
			joynr::PublicationManager* publicationManager,
			joynr::InProcessPublicationSender* inProcessPublicationSender,
			const std::string& proxyParticipantId,
			const std::string& providerParticipantId,
			std::shared_ptr<joynr::InProcessAddress> address
) :
	proxyParticipantId(proxyParticipantId),
	providerParticipantId(providerParticipantId),
	address(address),
	subscriptionManager(subscriptionManager),
	publicationManager(publicationManager),
	inProcessPublicationSender(inProcessPublicationSender)
{
}

bool «interfaceName»InProcessConnector::usesClusterController() const{
	return false;
}

«FOR attribute : getAttributes(serviceInterface)»
	«val returnType = cppStdTypeUtil.getTypeName(attribute)»
	«val attributeName = attribute.joynrName»
	«val setAttributeName = "set" + attribute.joynrName.toFirstUpper»
	«IF attribute.readable»
		«val getAttributeName = "get" + attribute.joynrName.toFirstUpper»
		void «interfaceName»InProcessConnector::«getAttributeName»(
					«returnType»& attributeValue
		) {
			assert(address);
			std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
			assert(caller);
			std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
			assert(«serviceInterface.interfaceCaller»);

			std::shared_ptr<joynr::Future<«returnType»> > future(new joynr::Future<«returnType»>());

			std::function<void(const «returnType»& «attributeName»)> onSuccess =
					[future] (const «returnType»& «attributeName») {
						future->onSuccess(«attributeName»);
					};

			std::function<void(const exceptions::ProviderRuntimeException&)> onError =
					[future] (const exceptions::ProviderRuntimeException& error) {
						future->onError(RequestStatusCode::ERROR, error);
					};

			//see header for more information
			«serviceInterface.interfaceCaller»->«getAttributeName»(onSuccess, onError);
			future->get(attributeValue);
		}

		std::shared_ptr<joynr::Future<«returnType»>> «interfaceName»InProcessConnector::«getAttributeName»Async(
				std::function<void(const «returnType»& «attributeName»)> onSuccess,
				std::function<void(const exceptions::JoynrException& error)> onError
		) {
			std::ignore = onError; // not used yet
			assert(address);
			std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
			assert(caller);
			std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
			assert(«serviceInterface.interfaceCaller»);

			std::shared_ptr<joynr::Future<«returnType»> > future(new joynr::Future<«returnType»>());

			std::function<void(const «returnType»& «attributeName»)> onSuccessWrapper =
					[future, onSuccess] (const «returnType»& «attributeName») {
						future->onSuccess(«attributeName»);
						if (onSuccess) {
							onSuccess(«attributeName»);
						}
					};

			std::function<void(const exceptions::ProviderRuntimeException&)> onErrorWrapper =
					[future, onError] (const exceptions::ProviderRuntimeException& error) {
						future->onError(RequestStatusCode::ERROR, error);
						if (onError) {
							onError(error);
						}
					};

			//see header for more information
			«serviceInterface.interfaceCaller»->«getAttributeName»(onSuccessWrapper, onErrorWrapper);
			return future;
		}

	«ENDIF»
	«IF attribute.writable»
		std::shared_ptr<joynr::Future<void>> «interfaceName»InProcessConnector::«setAttributeName»Async(
				«returnType» input,
				std::function<void(void)> onSuccess,
				std::function<void(const exceptions::JoynrException& error)> onError
		) {
			std::ignore = onError; // not used yet
			assert(address);
			std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
			assert(caller);
			std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
			assert(«serviceInterface.interfaceCaller»);

			std::shared_ptr<joynr::Future<void>> future(new joynr::Future<void>());
			std::function<void()> onSuccessWrapper =
					[future, onSuccess] () {
						future->onSuccess();
						if (onSuccess) {
							onSuccess();
						}
					};

			std::function<void(const exceptions::ProviderRuntimeException&)> onErrorWrapper =
					[future, onError] (const exceptions::ProviderRuntimeException& error) {
						future->onError(RequestStatusCode::ERROR, error);
						if (onError) {
							onError(error);
						}
					};

			//see header for more information
			LOG_ERROR(logger,"#### WARNING ##### «interfaceName»InProcessConnector::«setAttributeName»(Future) is synchronous.");
			«serviceInterface.interfaceCaller»->«setAttributeName»(input, onSuccessWrapper, onErrorWrapper);
			return future;
		}

		void «interfaceName»InProcessConnector::«setAttributeName»(
				const «returnType»& input
		) {
			assert(address);
			std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
			assert(caller);
			std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
			assert(«serviceInterface.interfaceCaller»);

			std::shared_ptr<joynr::Future<void>> future(new joynr::Future<void>());
			std::function<void()> onSuccess =
					[future] () {
						future->onSuccess();
					};

			std::function<void(const exceptions::ProviderRuntimeException&)> onError =
					[future] (const exceptions::ProviderRuntimeException& error) {
						future->onError(RequestStatusCode::ERROR, error);
					};

			//see header for more information
			«serviceInterface.interfaceCaller»->«setAttributeName»(input, onSuccess, onError);
			return future->get();
		}

	«ENDIF»
	«IF attribute.notifiable»
		std::string «interfaceName»InProcessConnector::subscribeTo«attributeName.toFirstUpper»(
				std::shared_ptr<joynr::ISubscriptionListener<«returnType»> > subscriptionListener,
				const joynr::SubscriptionQos& subscriptionQos,
				std::string& subscriptionId)
		{
			joynr::SubscriptionRequest subscriptionRequest;
			subscriptionRequest.setSubscriptionId(subscriptionId);
			return subscribeTo«attributeName.toFirstUpper»(subscriptionListener, subscriptionQos, subscriptionRequest);
		}

		std::string «interfaceName»InProcessConnector::subscribeTo«attributeName.toFirstUpper»(
				std::shared_ptr<joynr::ISubscriptionListener<«returnType»> > subscriptionListener,
				const joynr::SubscriptionQos& subscriptionQos)
		{
			joynr::SubscriptionRequest subscriptionRequest;
			return subscribeTo«attributeName.toFirstUpper»(subscriptionListener, subscriptionQos, subscriptionRequest);
		}

		std::string «interfaceName»InProcessConnector::subscribeTo«attributeName.toFirstUpper»(
				std::shared_ptr<joynr::ISubscriptionListener<«returnType»> > subscriptionListener,
				const joynr::SubscriptionQos& subscriptionQos,
				joynr::SubscriptionRequest& subscriptionRequest)
		{
			«IF isEnum(attribute.type)»
				Q_UNUSED(subscriptionListener);
				Q_UNUSED(subscriptionQos);
				// TODO support enum return values in C++ client
				LOG_FATAL(logger, "enum return values are currently not supported in C++ client (attribute name: «interfaceName».«attributeName»)");
				assert(false);
				// Visual C++ requires a return value
				return std::string();
			«ELSE»
				LOG_DEBUG(logger, "Subscribing to «attributeName».");
				assert(subscriptionManager != NULL);
				std::string attributeName("«attributeName»");
				auto subscriptionCallback = std::make_shared<
						joynr::SubscriptionCallback<«returnType»>
				>(subscriptionListener);
				subscriptionManager->registerSubscription(
						attributeName,
						subscriptionCallback,
						SubscriptionUtil::getVariant(subscriptionQos),
						subscriptionRequest);
				LOG_DEBUG(logger, FormatString("Registered subscription: %1")
						.arg(subscriptionRequest.toString()).str()
				);
				assert(address);
				std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
				assert(caller);
				std::shared_ptr<«interfaceName»RequestCaller> requestCaller = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
				std::string subscriptionId(subscriptionRequest.getSubscriptionId());

				if(!caller) {
					assert(publicationManager != NULL);
					/**
					* Provider not registered yet
					* Dispatcher will call publicationManger->restore when a new provider is added to activate
					* subscriptions for that provider
					*/
					publicationManager->add(proxyParticipantId, providerParticipantId, subscriptionRequest);
				} else {
					publicationManager->add(proxyParticipantId, providerParticipantId, caller, subscriptionRequest, inProcessPublicationSender);
				}
				return subscriptionId;
			«ENDIF»
		}

		void «interfaceName»InProcessConnector::unsubscribeFrom«attributeName.toFirstUpper»(
				std::string& subscriptionId
		) {
			«IF isEnum(attribute.type)»
				Q_UNUSED(subscriptionId);
				// TODO support enum return values in C++ client
				LOG_FATAL(logger, "enum return values are currently not supported in C++ client (attribute name: «interfaceName».«attributeName»)");
				assert(false);
			«ELSE»
				LOG_DEBUG(logger, FormatString("Unsubscribing. Id=%1").arg(subscriptionId).str());
				assert(publicationManager != NULL);
				LOG_DEBUG(logger, "Stopping publications by publication manager.");
				publicationManager->stopPublication(subscriptionId);
				assert(subscriptionManager != NULL);
				LOG_DEBUG(logger, "Unregistering attribute subscription.");
				subscriptionManager->unregisterSubscription(subscriptionId);
			«ENDIF»
		}

	«ENDIF»
«ENDFOR»

«FOR method: getMethods(serviceInterface)»
«var methodname = method.joynrName»
«var inputTypedParamList = cppStdTypeUtil.getCommaSeperatedTypedConstInputParameterList(method)»
«var outputParameters = cppStdTypeUtil.getCommaSeparatedOutputParameterTypes(method)»
«var inputParamList = cppStdTypeUtil.getCommaSeperatedUntypedInputParameterList(method)»
«var outputTypedConstParamList = cppStdTypeUtil.getCommaSeperatedTypedConstOutputParameterList(method)»
«var outputTypedParamList = cppStdTypeUtil.getCommaSeperatedTypedOutputParameterList(method)»
«var outputUntypedParamList = cppStdTypeUtil.getCommaSeperatedUntypedOutputParameterList(method)»

void «interfaceName»InProcessConnector::«methodname»(
		«outputTypedParamList»«IF method.outputParameters.size > 0 && method.inputParameters.size > 0», «ENDIF»«inputTypedParamList»
) {
	assert(address);
	std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
	assert(caller);
	std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
	assert(«serviceInterface.interfaceCaller»);
	std::shared_ptr<joynr::Future<«outputParameters»> > future(
			new joynr::Future<«outputParameters»>());

	std::function<void(«outputTypedConstParamList»)> onSuccess =
			[future] («outputTypedConstParamList») {
				future->onSuccess(
						«outputUntypedParamList»
				);
			};

	std::function<void(const exceptions::JoynrException&)> onError =
			[future] (const exceptions::JoynrException& error) {
				future->onError(RequestStatusCode::ERROR, error);
			};

	«serviceInterface.interfaceCaller»->«methodname»(«IF !method.inputParameters.empty»«inputParamList», «ENDIF»onSuccess, onError);
	future->get(«cppStdTypeUtil.getCommaSeperatedUntypedOutputParameterList(method)»);
}

std::shared_ptr<joynr::Future<«outputParameters»> > «interfaceName»InProcessConnector::«methodname»Async(«cppStdTypeUtil.getCommaSeperatedTypedConstInputParameterList(method)»«IF !method.inputParameters.empty»,«ENDIF»
			std::function<void(«outputTypedConstParamList»)> onSuccess,
			std::function<void(const exceptions::JoynrException& error)> onError)
{
	std::ignore = onError; // not used yet
	assert(address);
	std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
	assert(caller);
	std::shared_ptr<«interfaceName»RequestCaller> «serviceInterface.interfaceCaller» = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
	assert(«serviceInterface.interfaceCaller»);
	std::shared_ptr<joynr::Future<«outputParameters»> > future(
			new joynr::Future<«outputParameters»>());

	std::function<void(«outputTypedConstParamList»)> onSuccessWrapper =
			[future, onSuccess] («outputTypedConstParamList») {
				future->onSuccess(«outputUntypedParamList»);
				if (onSuccess)
				{
					onSuccess(«outputUntypedParamList»);
				}
			};

	std::function<void(const exceptions::JoynrException&)> onErrorWrapper =
			[future, onError] (const exceptions::JoynrException& error) {
				future->onError(RequestStatusCode::ERROR, error);
				if (onError) {
					onError(error);
				}
			};

	«serviceInterface.interfaceCaller»->«methodname»(«IF !method.inputParameters.empty»«inputParamList», «ENDIF»onSuccessWrapper, onErrorWrapper);
	return future;
}

«ENDFOR»

«FOR broadcast: serviceInterface.broadcasts»
	«val returnTypes = cppStdTypeUtil.getCommaSeparatedOutputParameterTypes(broadcast)»
	«val broadcastName = broadcast.joynrName»

	«IF isSelective(broadcast)»
		std::string «interfaceName»InProcessConnector::subscribeTo«broadcastName.toFirstUpper»Broadcast(
				const «interfaceName.toFirstUpper»«broadcastName.toFirstUpper»BroadcastFilterParameters& filterParameters,
				std::shared_ptr<joynr::ISubscriptionListener<«returnTypes» > > subscriptionListener,
				const joynr::OnChangeSubscriptionQos& subscriptionQos
	«ELSE»
		std::string «interfaceName»InProcessConnector::subscribeTo«broadcastName.toFirstUpper»Broadcast(
				std::shared_ptr<joynr::ISubscriptionListener<«returnTypes» > > subscriptionListener,
				const joynr::OnChangeSubscriptionQos& subscriptionQos
	«ENDIF»
	) {
		LOG_DEBUG(logger, "Subscribing to «broadcastName».");
		assert(subscriptionManager != NULL);
		std::string broadcastName("«broadcastName»");
		joynr::BroadcastSubscriptionRequest subscriptionRequest;
		«IF isSelective(broadcast)»
			subscriptionRequest.setFilterParameters(filterParameters);
		«ENDIF»
		return subscribeTo«broadcastName.toFirstUpper»Broadcast(
					subscriptionListener,
					subscriptionQos,
					subscriptionRequest);
	}

	«IF isSelective(broadcast)»
		std::string «interfaceName»InProcessConnector::subscribeTo«broadcastName.toFirstUpper»Broadcast(
				const «interfaceName.toFirstUpper»«broadcastName.toFirstUpper»BroadcastFilterParameters& filterParameters,
				std::shared_ptr<joynr::ISubscriptionListener<«returnTypes» > > subscriptionListener,
				const joynr::OnChangeSubscriptionQos& subscriptionQos,
				std::string& subscriptionId
	«ELSE»
		std::string «interfaceName»InProcessConnector::subscribeTo«broadcastName.toFirstUpper»Broadcast(
				std::shared_ptr<joynr::ISubscriptionListener<«returnTypes» > > subscriptionListener,
				const joynr::OnChangeSubscriptionQos& subscriptionQos,
				std::string& subscriptionId
	«ENDIF»
	) {
		joynr::BroadcastSubscriptionRequest subscriptionRequest;
		«IF isSelective(broadcast)»
			subscriptionRequest.setFilterParameters(filterParameters);
		«ENDIF»
		subscriptionRequest.setSubscriptionId(subscriptionId);
		return subscribeTo«broadcastName.toFirstUpper»Broadcast(
					subscriptionListener,
					subscriptionQos,
					subscriptionRequest);
	}

	std::string «interfaceName»InProcessConnector::subscribeTo«broadcastName.toFirstUpper»Broadcast(
			std::shared_ptr<joynr::ISubscriptionListener<«returnTypes» > > subscriptionListener,
			const joynr::OnChangeSubscriptionQos& subscriptionQos,
			joynr::BroadcastSubscriptionRequest& subscriptionRequest
	) {
		LOG_DEBUG(logger, "Subscribing to «broadcastName».");
		assert(subscriptionManager != NULL);
		std::string broadcastName("«broadcastName»");

		auto subscriptionCallback = std::make_shared<
				joynr::SubscriptionCallback<«returnTypes»>
		>(subscriptionListener);
		subscriptionManager->registerSubscription(
					broadcastName,
					subscriptionCallback,
					Variant::make<OnChangeSubscriptionQos>(subscriptionQos),
					subscriptionRequest);
		LOG_DEBUG(logger, FormatString("Registered broadcast subscription: %1").arg(subscriptionRequest.toString()).str());
		assert(address);
		std::shared_ptr<joynr::RequestCaller> caller = address->getRequestCaller();
		assert(caller);
		std::shared_ptr<«interfaceName»RequestCaller> requestCaller = std::dynamic_pointer_cast<«interfaceName»RequestCaller>(caller);
		std::string subscriptionId(subscriptionRequest.getSubscriptionId());

		if(!caller) {
			assert(publicationManager != NULL);
			/**
			* Provider not registered yet
			* Dispatcher will call publicationManger->restore when a new provider is added to activate
			* subscriptions for that provider
			*/
			publicationManager->add(proxyParticipantId, providerParticipantId, subscriptionRequest);
		} else {
			publicationManager->add(
						proxyParticipantId,
						providerParticipantId,
						caller,
						subscriptionRequest,
						inProcessPublicationSender);
		}
		return subscriptionId;
	}

	void «interfaceName»InProcessConnector::unsubscribeFrom«broadcastName.toFirstUpper»Broadcast(
			std::string& subscriptionId
	) {
		LOG_DEBUG(logger, FormatString("Unsubscribing broadcast. Id=%1").arg(subscriptionId).str());
		assert(publicationManager != NULL);
		LOG_DEBUG(logger, "Stopping publications by publication manager.");
		publicationManager->stopPublication(subscriptionId);
		assert(subscriptionManager != NULL);
		LOG_DEBUG(logger, "Unregistering broadcast subscription.");
		subscriptionManager->unregisterSubscription(subscriptionId);
	}
«ENDFOR»
«getNamespaceEnder(serviceInterface)»
'''

	def getInterfaceCaller(FInterface serviceInterface){
		serviceInterface.joynrName.toFirstLower + "Caller"
	}
}
