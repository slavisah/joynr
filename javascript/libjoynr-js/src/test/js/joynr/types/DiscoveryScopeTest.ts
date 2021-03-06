/*eslint global-require: "off"*/
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

import DiscoveryScope1 from "joynr/joynr/types/DiscoveryScope";
import DiscoveryScope2 from "joynr/generated/joynr/types/DiscoveryScope";

describe("libjoynr-js.joynr.types.DiscoveryScope", () => {
    it("can require DiscoveryScope from both paths and it's the same", () => {
        expect(DiscoveryScope1).toBeDefined();
        expect(DiscoveryScope1).toBe(DiscoveryScope2);
    });
});
