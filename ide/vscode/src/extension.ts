import * as vscode from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from "vscode-languageclient/node";

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration("rockit.lsp");
  const enabled = config.get<boolean>("enabled", true);
  if (!enabled) {
    return;
  }

  const rockitPath = config.get<string>("path", "rockit");

  const serverOptions: ServerOptions = {
    command: rockitPath,
    args: ["lsp"],
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: "file", language: "rockit" },
    ],
  };

  client = new LanguageClient(
    "rockitLSP",
    "Rockit Language Server",
    serverOptions,
    clientOptions
  );

  client.start();
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
