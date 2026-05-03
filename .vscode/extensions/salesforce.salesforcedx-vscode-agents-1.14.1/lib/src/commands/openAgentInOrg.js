"use strict";
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
exports.registerOpenAgentInOrgCommand = void 0;
const vscode = __importStar(require("vscode"));
const commands_1 = require("../enums/commands");
const coreExtensionService_1 = require("../services/coreExtensionService");
const agentUtils_1 = require("./agentUtils");
const logger_1 = require("../utils/logger");
const registerOpenAgentInOrgCommand = () => {
    return vscode.commands.registerCommand(commands_1.Commands.openAgentInOrg, async (uri) => {
        const telemetryService = coreExtensionService_1.CoreExtensionService.getTelemetryService();
        const logger = new logger_1.Logger(coreExtensionService_1.CoreExtensionService.getChannelService());
        const commandName = commands_1.Commands.openAgentInOrg;
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
                const { conn, org } = await (0, agentUtils_1.getConnectionAndProject)();
                // Query BotDefinition to get the Bot ID (same as CLI does)
                // Escape single quotes in agent name to prevent SQL injection
                const escapedAgentName = agentName.replace(/'/g, "''");
                const query = `SELECT Id FROM BotDefinition WHERE DeveloperName='${escapedAgentName}'`;
                const result = await conn.singleRecordQuery(query, { tooling: false });
                if (!result?.Id) {
                    vscode.window.showErrorMessage(`Agent "${agentName}" not found in org.`);
                    logger.error(`Agent "${agentName}" not found in org.`);
                    logger.debug('Suggestion: Ensure the agent is deployed to your org with the "project deploy start" CLI command.');
                    telemetryService?.sendException('agent_not_found', `Agent "${agentName}" not found in org`);
                    return;
                }
                const botId = result.Id;
                // Construct the Agent Builder redirect URL (same as CLI)
                const redirectUri = `AiCopilot/copilotStudio.app#/copilot/builder?copilotId=${botId}`;
                // Generate frontdoor URL with authentication
                const frontdoorUrl = await org.getFrontDoorUrl(redirectUri);
                // Open in browser using VS Code
                // Cast to any to prevent VS Code from parsing/encoding the URL
                // This preserves the already-encoded URL exactly as-is
                await vscode.env.openExternal(frontdoorUrl); // doesn't change string
                vscode.window.showInformationMessage('Agent opened successfully in the default org.');
            }
            catch (error) {
                (0, agentUtils_1.handleCommandError)(error, 'Unable to open agent', 'open_agent_failed', logger, telemetryService);
            }
        });
    });
};
exports.registerOpenAgentInOrgCommand = registerOpenAgentInOrgCommand;
//# sourceMappingURL=openAgentInOrg.js.map