"use strict";
/*
 * Copyright 2025, Salesforce, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerOpenAuthoringBundleInOrgCommand = void 0;
const vscode = __importStar(require("vscode"));
const commands_1 = require("../enums/commands");
const coreExtensionService_1 = require("../services/coreExtensionService");
const agentUtils_1 = require("./agentUtils");
const logger_1 = require("../utils/logger");
const registerOpenAuthoringBundleInOrgCommand = () => {
    return vscode.commands.registerCommand(commands_1.Commands.openAuthoringBundleInOrg, async (uri) => {
        const telemetryService = coreExtensionService_1.CoreExtensionService.getTelemetryService();
        const logger = new logger_1.Logger(coreExtensionService_1.CoreExtensionService.getChannelService());
        const commandName = commands_1.Commands.openAuthoringBundleInOrg;
        const hrstart = process.hrtime();
        telemetryService?.sendCommandEvent(commandName, hrstart, { commandName });
        let agentName;
        // If called from context menu with a file/directory, use that to determine the agent
        if (uri?.fsPath) {
            try {
                agentName = await (0, agentUtils_1.getAgentNameFromPath)(uri.fsPath);
            }
            catch (error) {
                console.warn('Failed to get agent name from path, falling back to picker:', error);
            }
        }
        // If no agent name from context, prompt user to select
        if (!agentName) {
            agentName = await (0, agentUtils_1.selectAgentFromProject)(logger, telemetryService);
            if (!agentName) {
                return;
            }
        }
        await vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'Open Agent in Org',
            cancellable: true
        }, async (progress) => {
            progress.report({ message: `Opening ${agentName}` });
            try {
                // Get org connection
                const { org } = await (0, agentUtils_1.getConnectionAndProject)();
                // For aiAuthoringBundles (.agent files), use the agent authoring builder URL
                // URL format: AgentAuthoring/agentAuthoringBuilder.app#/project?projectName=AgentName
                const redirectUri = `AgentAuthoring/agentAuthoringBuilder.app#/project?projectName=${encodeURIComponent(agentName)}`;
                // Generate frontdoor URL with authentication
                const frontdoorUrl = await org.getFrontDoorUrl(redirectUri);
                // Open in browser using VS Code
                // Cast to any to prevent VS Code from parsing/encoding the URL
                // This preserves the already-encoded URL exactly as-is
                await vscode.env.openExternal(frontdoorUrl); // doesn't change string
                vscode.window.showInformationMessage('Agent opened successfully in the default org.');
            }
            catch (error) {
                (0, agentUtils_1.handleCommandError)(error, 'Unable to open agent', 'open_agent_authoring_failed', logger, telemetryService);
            }
        });
    });
};
exports.registerOpenAuthoringBundleInOrgCommand = registerOpenAuthoringBundleInOrgCommand;
//# sourceMappingURL=openAuthoringBundleInOrg.js.map