using Godot;
using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

public partial class auto_updater : Node {

    [Export] public string exeUrl = "https://github.com/StarDeception/StarDeception/releases/download/test/StarDeception.windows.exe";
    [Export] public string hashUrl = "https://github.com/StarDeception/StarDeception/releases/download/test/hash.sha256";
    [Export] public string updaterUrl = "https://github.com/StarDeception/StarDeception/releases/download/test/SDUpdater.exe";
    [Export] public string expectedHash = ""; // SHA256 attendu par défaut (bf2d3a65ffa3ab8c1de8f7fa15ed0a22552a15913fbbd74caf9da38d33db7528)
    [Export] public string saveHashPath = "user://hash.sha256"; // Emplacement local
    [Export] public string savePathExe = "user://StarDeception.windows.exe"; // Emplacement local de l'exe
    [Export] public string saveUpdaterPath = "user://SDUpdater.exe"; // Emplacement local de l'exe
    byte[] hash_body = null;
    RichTextLabel statusLabel;

    public override void _Ready() {
        statusLabel = GetNode<RichTextLabel>("hint_text");
        statusLabel.Clear();

        if (Engine.IsEditorHint() || OS.HasFeature("editor")) {
            AddLog("Vous êtes dans l'editeur, pas de MAJ vérifiée !", "00FFAA");
            return;
        }
        AddLog("Dossier de l'exe en cours : " + OS.GetExecutablePath());

        if (OS.HasFeature("linux")) {
            saveUpdaterPath = "user://SDUpdater.sh";
            updaterUrl = "https://github.com/StarDeception/StarDeception/releases/download/test/SDUpdater.sh";
        }

        //Téléchargement de l'updater
        if (!FileAccess.FileExists(saveUpdaterPath)) {
            AddLog("Téléchargement de l'updater : " + updaterUrl + "...", "AAFF00");
            HttpRequest req = new HttpRequest();
            AddChild(req);
            req.RequestCompleted += OnRequestUpdaterCompleted;
            Error err = req.Request(updaterUrl);
            if (err != Error.Ok) {
                AddLog("Erreur de requête HTTP : " + err, "FF0000");
            }
        } else {
            CheckForUpdate();
        }
    }

    void CheckForUpdate() {
        AddLog($"Dossier utilisateur : {ProjectSettings.GlobalizePath("user://")}", "666666");

        //vérification d'un .sha256 déjà présent (maj déjà vérifiée)
        if (FileAccess.FileExists(saveHashPath)) {
            var file_hash = FileAccess.Open(saveHashPath, FileAccess.ModeFlags.Read);
            expectedHash = Encoding.UTF8.GetString(file_hash.GetBuffer((long)file_hash.GetLength()));
            AddLog("Hash en cache : " + expectedHash, "666666");
        } else {
            AddLog("Pas de .sha256 en cache, utilisation du hash par défaut : " + expectedHash, "FFFF00");
        }

        //requêtte du .sha256 dans /release
        HttpRequest req = new HttpRequest();
        AddChild(req);
        req.RequestCompleted += OnRequestHashCompleted;

        AddLog("Téléchargement du fichier " + hashUrl, "a2d8fc");
        Error err = req.Request(hashUrl);
        if (err != Error.Ok) {
            AddLog("Erreur de requête HTTP : " + err, "FF0000");
        }
    }

    private void OnRequestUpdaterCompleted(long result, long responseCode, string[] headers, byte[] body) {
        if (result != (long)HttpRequest.Result.Success || responseCode != 200) {
            AddLog("Échec de téléchargement de l'updater : " + responseCode, "FF0000");
            return;
        }

        var file = FileAccess.Open(saveUpdaterPath, FileAccess.ModeFlags.Write);
        file.StoreBuffer(body);
        file.Close();

        if (OS.HasFeature("linux")) {
            FileAccess file2 = FileAccess.Open("user://updater.sh", FileAccess.ModeFlags.Read);
            OS.Execute("chmod", new[] { "+x", ProjectSettings.GlobalizePath("user://SDUpdater.sh") });
            savePathExe = "user://StarDeception.linux.x86_64 ";
            exeUrl = "https://github.com/StarDeception/StarDeception/releases/download/test/StarDeception.linux.x86_64 ";
        }

        AddLog("Updater téléchargé avec succès :) > " + saveUpdaterPath, "00FF00");
        CheckForUpdate();
    }

    private void OnRequestHashCompleted(long result, long responseCode, string[] headers, byte[] body) {
        if (result != (long)HttpRequest.Result.Success || responseCode != 200) {
            AddLog("Échec de téléchargement : " + responseCode, "FF0000");
            return;
        }

        string hash = Encoding.UTF8.GetString(body);
        AddLog("Version SHA256 téléchargé : " + Encoding.UTF8.GetString(body), "00AAFF");

        if (hash != expectedHash) {
            hash_body = body;
            AddLog("Hash invalide ! " + hash + " vs " + expectedHash, "fb7d50");
            HttpRequest req = new HttpRequest();
            AddChild(req);
            req.RequestCompleted += OnRequestExeCompleted;

            AddLog("Téléchargement du fichier " + exeUrl, "fbb450");
            Error err = req.Request(exeUrl);
            if (err != Error.Ok) {
                AddLog("Erreur de requête HTTP : " + err, "FF0000");
            }
            return;
        } else {
            AddLog("Hash valide :)", "00FF00");
        }
    }

    private void OnRequestExeCompleted(long result, long responseCode, string[] headers, byte[] body) {
        if (result != (long)HttpRequest.Result.Success || responseCode != 200) {
            AddLog("Échec de téléchargement : " + responseCode, "FF0000");
            return;
        }

        var file_hash = FileAccess.Open(saveHashPath, FileAccess.ModeFlags.Write);
        file_hash.StoreBuffer(hash_body);
        file_hash.Close();

        var file = FileAccess.Open(savePathExe, FileAccess.ModeFlags.Write);
        file.StoreBuffer(body);
        file.Close();

        AddLog("Fichier .exe sauvegardé à : " + savePathExe, "d8d8d8");
        AddLog("Fichier .sha256 sauvegardé à : " + saveHashPath, "dbe9d3");

        LaunchUpdater();
    }

    void LaunchUpdater() {
        string oldExePath = OS.GetExecutablePath();
        //fermeture exe et auto maj
        if (OS.HasFeature("windows")) {
            if (!FileAccess.FileExists("user://SDUpdater.exe")) {
                AddLog("Updater introuvable !", "FF0000");
                return;
            }
            var pid = OS.CreateProcess(ProjectSettings.GlobalizePath("user://SDUpdater.exe"), new string[] { oldExePath, ProjectSettings.GlobalizePath("user://StarDeception.windows.exe") }, true);
            AddLog("Lancement de " + "user://SDUpdater.exe,  PID " + pid, "00FFFF");
        } else if (OS.HasFeature("linux")) {
            OS.CreateProcess("/bin/bash", new string[] { ProjectSettings.GlobalizePath("user://SDUpdater.sh"), oldExePath, ProjectSettings.GlobalizePath("user://StarDeception.linux.x86_64") }, true);
        }

        GetTree().Quit();
    }

    private string ComputeSHA256(byte[] data) {
        using SHA256 sha = SHA256.Create();
        byte[] hashBytes = sha.ComputeHash(data);
        StringBuilder sb = new StringBuilder();
        foreach (byte b in hashBytes)
            sb.Append(b.ToString("x2")); // Hex format
        return sb.ToString();
    }

    void AddLog(string log, string hexCode = "FFFFFF") {
        statusLabel.AppendText($"[color=#{hexCode}]{log}[/color]\n");
    }
}
