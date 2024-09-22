// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from "vscode";

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
  // Use the console to output diagnostic information (console.log) and errors (console.error)
  // This line of code will only be executed once when your extension is activated
  console.log('Congratulations, your extension "codemods" is now active!');

  let tabToMove: { viewColumn: number; tabUri: string } | null = null;
  let moveEditorToNewWindowTimer: NodeJS.Timeout | null = null;

  const flushMoveEditors = () => {
    vscode.commands.executeCommand("workbench.action.moveEditorToNewWindow");
    tabToMove = null;
    moveEditorToNewWindowTimer = null;
  };

  const getTabURI = (tab: vscode.Tab) => {
    if (tab.input && tab.input instanceof Object && "uri" in tab.input) {
      return (tab.input.uri as vscode.Uri).toString();
    }

    return null;
  };

  vscode.commands.registerCommand(
    "codemods.openTerminalInNewWindow",
    async () => {
      await vscode.commands.executeCommand(
        "workbench.action.createTerminalEditor",
      );
      await vscode.commands.executeCommand(
        "workbench.action.moveEditorToNewWindow",
      );
    },
  );

  const disposable = vscode.window.tabGroups.onDidChangeTabs((change) => {
    const opened = change.opened[0];
    const closed = change.closed[0];

    console.log(opened, closed);

    if (opened && opened.group.tabs.length > 1) {
      // vscode extension / settings windows
      // these can't be split out into a new window
      if (opened.input === undefined) {
        return;
      }

      // images / things with custom view type
      // also can't be split out
      if ("viewType" in (opened.input as {})) {
        return;
      }

      const uri = getTabURI(opened);

      if (!uri) {
        return;
      }

      tabToMove = {
        viewColumn: opened.group.viewColumn,
        tabUri: uri,
      };

      if (moveEditorToNewWindowTimer) {
        clearTimeout(moveEditorToNewWindowTimer);
      }

      moveEditorToNewWindowTimer = setTimeout(flushMoveEditors, 20);
    }

    // If the tab that was closed was the one we were trying to move, cancel the move
    // this means vscode is trying to move tabs from a closed window to the current one
    // but we would prefer the tabs be closed
    if (closed && getTabURI(closed) === tabToMove?.tabUri) {
      // Cancel flush
      clearTimeout(moveEditorToNewWindowTimer!);
      moveEditorToNewWindowTimer = null;

      // Close the recently opened tab we were going to
      // move to the new window
      const groups = vscode.window.tabGroups;
      const group = groups.all.find(
        (group) => group.viewColumn === tabToMove?.viewColumn,
      );

      if (!group) {
        return;
      }

      const tab = group.tabs.find(
        (tab) => getTabURI(tab) === tabToMove?.tabUri,
      );

      if (!tab) {
        return;
      }

      groups.close(tab);

      tabToMove = null;
    }
  });

  context.subscriptions.push(disposable);
}

// This method is called when your extension is deactivated
export function deactivate() {}
