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
exports.getConnectionAndProject = getConnectionAndProject;
exports.selectAgentFromProject = selectAgentFromProject;
exports.handleCommandError = handleCommandError;
exports.getPublishedAgents = getPublishedAgents;
exports.getAgentNameFromPath = getAgentNameFromPath;
exports.getAgentNameFromFile = getAgentNameFromFile;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const core_1 = require("@salesforce/core");
const agents_1 = require("@salesforce/agents");
const UNSUPPORTED_AGENTS = ['Copilot_for_Salesforce'];
async function getConnectionAndProject() {
    const configAggregator = await core_1.ConfigAggregator.create();
    const targetOrg = configAggregator.getPropertyValue('target-org');
    if (!targetOrg) {
        throw new Error('No default org configured. Set a target org with "sf config set target-org".');
    }
    const org = await core_1.Org.create({ aliasOrUsername: targetOrg });
    return { conn: org.getConnection(), project: core_1.SfProject.getInstance(), org };
}
/**
 * Prompts user to select an agent from the current DX project.
 * Returns undefined if no agent is selected or no agents are available.
 */
async function selectAgentFromProject(logger, telemetryService) {
    const project = core_1.SfProject.getInstance();
    const agents = await agents_1.Agent.list(project);
    if (agents.length === 0) {
        vscode.window.showErrorMessage(`Couldn't find any agents in the current DX project.`);
        logger.error("Couldn't find any agents in the current DX project.");
        logger.debug('Suggestion: Retrieve your agent metadata to your DX project with the "project retrieve start" CLI command.');
        return undefined;
    }
    const agentName = await vscode.window.showQuickPick(agents, { placeHolder: 'Agent name (type to search)' });
    if (!agentName) {
        telemetryService?.sendException('no_agent_selected', 'No Agent selected');
        return undefined;
    }
    return agentName;
}
/**
 * Handles command errors with consistent messaging and telemetry.
 */
function handleCommandError(error, userMessage, exceptionName, logger, telemetryService) {
    const sfError = core_1.SfError.wrap(error);
    const errorMessage = sfError.message;
    vscode.window.showErrorMessage(`${userMessage}: ${errorMessage}`);
    logger.error(`${userMessage}: ${errorMessage}`, sfError);
    telemetryService?.sendException(exceptionName, errorMessage);
}
async function getPublishedAgents(conn) {
    const agents = await agents_1.Agent.listRemote(conn);
    return agents
        .filter(a => !a.IsDeleted && !UNSUPPORTED_AGENTS.includes(a.DeveloperName))
        .map(a => ({
        name: a.DeveloperName,
        id: a.Id,
        isActivated: a.BotVersions.records.some(v => v.Status === 'Active' && !v.IsDeleted)
    }));
}
/**
 * Gets the agent name from a directory path or file path.
 * Handles both file selections and directory selections.
 */
async function getAgentNameFromPath(targetPath) {
    // First check if this is in a genAiPlannerBundles directory
    const plannerBundleAgentName = getAgentNameFromPlannerBundlePath(targetPath);
    if (plannerBundleAgentName) {
        return plannerBundleAgentName;
    }
    // Then check if this is in an aiAuthoringBundles directory
    const authoringBundleAgentName = getAgentNameFromAuthoringBundlePath(targetPath);
    if (authoringBundleAgentName) {
        return authoringBundleAgentName;
    }
    const stat = await vscode.workspace.fs.stat(vscode.Uri.file(targetPath));
    if (stat.type === vscode.FileType.Directory) {
        // If it's a directory, look for a .bot-meta.xml file in it
        return getAgentNameFromDirectory(targetPath);
    }
    else {
        // If it's a file, use the existing logic
        const fileName = path.basename(targetPath);
        return getAgentNameFromFile(fileName, targetPath);
    }
}
// Extracts agent name from bundle paths (genAiPlannerBundles or aiAuthoringBundles)
function getAgentNameFromBundlePath(targetPath, bundleDir, stripExtension, stripVersionSuffix = false) {
    // Normalize to handle cross-platform path separators (/ on Unix, \ on Windows)
    const normalizedPath = path.normalize(targetPath);
    const pathParts = normalizedPath.split(path.sep);
    const bundleIndex = pathParts.findIndex(part => part === bundleDir);
    if (bundleIndex === -1 || bundleIndex >= pathParts.length - 1) {
        return null;
    }
    // The agent name is the first item after the bundle directory
    let agentIdentifier = pathParts[bundleIndex + 1];
    // Remove extension if specified
    if (stripExtension && agentIdentifier.endsWith(stripExtension)) {
        agentIdentifier = agentIdentifier.replace(stripExtension, '');
    }
    // Remove version suffix if requested
    if (stripVersionSuffix) {
        agentIdentifier = agentIdentifier.replace(/_v\d+$/, '');
    }
    return agentIdentifier;
}
// Returns agent name from genAiPlannerBundles path
function getAgentNameFromPlannerBundlePath(targetPath) {
    return getAgentNameFromBundlePath(targetPath, 'genAiPlannerBundles', '.genAiPlannerBundle', true);
}
// Returns agent name from aiAuthoringBundles path
function getAgentNameFromAuthoringBundlePath(targetPath) {
    return getAgentNameFromBundlePath(targetPath, 'aiAuthoringBundles');
}
/**
 * Helper to find .bot-meta.xml file in a directory and extract agent name.
 * Returns null if not found.
 */
async function findBotMetaXmlInDirectory(directoryPath) {
    try {
        const dirUri = vscode.Uri.file(directoryPath);
        const files = await vscode.workspace.fs.readDirectory(dirUri);
        const botMetaFile = files.find(([name, type]) => type === vscode.FileType.File && name.endsWith('.bot-meta.xml'));
        if (botMetaFile) {
            return botMetaFile[0].replace('.bot-meta.xml', '');
        }
        return null;
    }
    catch (error) {
        return null;
    }
}
/**
 * Extracts the agent name from a directory by looking for a .bot-meta.xml file.
 */
async function getAgentNameFromDirectory(directoryPath) {
    const agentName = await findBotMetaXmlInDirectory(directoryPath);
    if (agentName) {
        return agentName;
    }
    // Fallback: use the directory name
    return path.basename(directoryPath);
}
/**
 * Extracts the agent name from the given file or directory.
 * For .bot-meta.xml files, returns the filename without extension.
 * For .botVersion-meta.xml files, looks for a .bot-meta.xml file in the same directory
 * and returns that filename without extension.
 * For directories, looks for a .bot-meta.xml file in the directory.
 */
async function getAgentNameFromFile(fileName, filePath) {
    // For bot metadata files, extract agent name from filename
    if (fileName.endsWith('.bot-meta.xml')) {
        return fileName.replace('.bot-meta.xml', '');
    }
    // For genAiPlannerBundle files, extract agent name from filename
    if (fileName.endsWith('.genAiPlannerBundle')) {
        // Remove the .genAiPlannerBundle extension
        let agentName = fileName.replace('.genAiPlannerBundle', '');
        // Remove version suffix (e.g., _v1, _v2, etc.)
        agentName = agentName.replace(/_v\d+$/, '');
        return agentName;
    }
    // For bot version metadata files, find the corresponding .bot-meta.xml file in the same directory
    if (fileName.endsWith('.botVersion-meta.xml')) {
        try {
            const directory = path.dirname(filePath);
            const agentName = await findBotMetaXmlInDirectory(directory);
            if (agentName) {
                return agentName;
            }
            // Fallback: try to infer from the file path structure
            // Bot version files are typically in: force-app/main/default/botVersions/{botName}/{versionName}.botVersion-meta.xml
            const pathParts = filePath.split(path.sep);
            const botVersionIndex = pathParts.findIndex(part => part === 'botVersions');
            if (botVersionIndex >= 0 && botVersionIndex < pathParts.length - 2) {
                return pathParts[botVersionIndex + 1]; // The bot name is the directory after 'botVersions'
            }
            // Last fallback: use the version name (original behavior)
            return fileName.replace('.botVersion-meta.xml', '');
        }
        catch (error) {
            console.warn('Failed to find bot metadata file in directory, falling back to filename:', error);
            return fileName.replace('.botVersion-meta.xml', '');
        }
    }
    return fileName;
}
//# sourceMappingURL=agentUtils.js.map