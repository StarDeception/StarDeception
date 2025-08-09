using Godot;
using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

public partial class AutoUpdater : RichTextLabel {

    string repo_url = "https://github.com/StarDeception/StarDeception/releases/download/test/";
    public string exeUrl;
    public string hashUrl;
    public string updaterUrl;

    public string expectedHash = ""; // SHA256 attendu par défaut (bf2d3a65ffa3ab8c1de8f7fa15ed0a22552a15913fbbd74caf9da38d33db7528)
    public string saveHashPath = "user://hash.sha256"; // Emplacement local
    public string saveExePath = "user://StarDeception.windows.exe"; // Emplacement local de l'exe
    public string saveUpdaterPath = "user://SDUpdater.exe"; // Emplacement local de l'exe
    RichTextLabel statusLabel;

    public override async void _Ready() {
        //définition des fichiers à télécharger sur le repo git
        exeUrl = repo_url + "StarDeception.windows.exe";
        hashUrl = repo_url + "hash.sha256";
        updaterUrl = repo_url + "SDUpdater.exe";

        statusLabel = this;
        statusLabel.Clear();

        //si dans l'éditeur, pas de check
        if (Engine.IsEditorHint() || OS.HasFeature("editor")) {
            AddLog("Vous êtes dans l'editeur, pas de MAJ vérifiée !", "00FFAA");
            return;
        }

        if (OS.HasFeature("linux")) {
            saveUpdaterPath = "user://SDUpdater.sh";
            updaterUrl = repo_url + "SDUpdater.sh";
        }

        //Téléchargement de l'updater
        if (!FileAccess.FileExists(saveUpdaterPath)) {
            var bytes = await DownloadFromHttp(updaterUrl);
            SaveBinaryOnDisk(saveUpdaterPath, bytes);

            if (OS.HasFeature("linux")) {
                FileAccess file2 = FileAccess.Open(saveUpdaterPath, FileAccess.ModeFlags.Read);
                OS.Execute("chmod", new[] { "+x", ProjectSettings.GlobalizePath("user://SDUpdater.sh") });
                file2.Close();
                saveExePath = "user://StarDeception.linux.x86_64";
                exeUrl = repo_url + "StarDeception.linux.x86_64";
            }

            AddLog("Updater téléchargé avec succès :) > " + saveUpdaterPath, "00FF00");
        }

        await CheckForUpdateAsync();
    }

    /// <summary>
    /// sauvegarde un buffer binaire sur le disque (dans notre cas dans le dossier user)
    /// </summary>
    /// <param name="filename"></param>
    /// <param name="bin"></param>
    void SaveBinaryOnDisk(string filename, byte[] bin) {
        var file = FileAccess.Open(filename, FileAccess.ModeFlags.Write);
        int chunkSize = 8192;
        for (int i = 0; i < bin.Length; i += chunkSize) {
            int size = Math.Min(chunkSize, bin.Length - i);
            file.StoreBuffer(bin.AsSpan(i, size).ToArray());
        }
        file.Flush();
        file.Close();
        AddLog($"Fichier {filename} sauvegardé !", "d8d8d8");
    }

    /// <summary>
    /// vérifie les MAJ via le fichier hash.sha256 de github contenant le hash de l'exe
    /// </summary>
    /// <returns></returns>
    async Task CheckForUpdateAsync() {
        AddLog($"Dossier utilisateur : {ProjectSettings.GlobalizePath("user://")}", "666666");

        //vérification d'un .sha256 déjà présent (maj déjà vérifiée)
        if (FileAccess.FileExists(saveHashPath)) {
            var file_hash = FileAccess.Open(saveHashPath, FileAccess.ModeFlags.Read);
            expectedHash = Encoding.UTF8.GetString(file_hash.GetBuffer((long)file_hash.GetLength()));
            AddLog("Hash en cache : " + expectedHash, "666666");
        } else {
            AddLog("Pas de hash.sha256 en cache, téléchargement...", "FFFF00");
        }

        //requêtte du .sha256 dans /release
        byte[] hash_bin = await DownloadFromHttp(hashUrl);
        string hash = Encoding.UTF8.GetString(hash_bin);
        AddLog("Version SHA256 téléchargé : " + hash, "00AAFF");

        if (hash != expectedHash) {
            AddLog("Hash client invalide !", "fb7d50");
            byte[] exe_bin = await DownloadFromHttp(exeUrl);
            SaveBinaryOnDisk(saveHashPath, hash_bin);
            SaveBinaryOnDisk(saveExePath, exe_bin);
            AddLog("Le client va se fermer et se relancer à jour dans 3 secondes...", "22FF33");
            await ToSignal(GetTree().CreateTimer(3.0), "timeout");
            LaunchUpdater();
        } else {
            AddLog("Hash valide :)", "00FF00");
        }
    }

    /// <summary>
    /// télécharge un fichier via HTTP
    /// </summary>
    /// <param name="url"></param>
    /// <returns></returns>
    private async Task<byte[]> DownloadFromHttp(string url) {
        AddLog("Téléchargement de : " + url.Replace(repo_url, "[github]/") + "...", "c385fb");

        HttpRequest req = new HttpRequest();
        AddChild(req);

        var tcs = new TaskCompletionSource<byte[]>();

        void OnCompleted(long result, long responseCode, string[] headers, byte[] body) {
            req.RequestCompleted -= OnCompleted;
            req.QueueFree();

            if (result != (long)HttpRequest.Result.Success || responseCode != 200) {
                AddLog($"Erreur HTTP : Code {responseCode}", "FF0000");
                tcs.SetResult(Array.Empty<byte>());
            } else {
                tcs.SetResult(body);
            }
        }

        req.RequestCompleted += OnCompleted;
        var err = req.Request(url);
        if (err != Error.Ok) {
            AddLog("Erreur de requête HTTP : " + err, "FF0000");
            req.QueueFree();
            return Array.Empty<byte>();
        }

        return await tcs.Task;
    }

    /// <summary>
    /// lance le script de copie du nouvel exe téléchargé vers l'actuel
    /// </summary>
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

    /// <summary>
    /// ajoute un log à la fenêtre pour info client
    /// </summary>
    /// <param name="log"></param>
    /// <param name="hexCode"></param>
    void AddLog(string log, string hexCode = "FFFFFF") {
        statusLabel.AppendText($"[color=#{hexCode}]{log}[/color]\n");
    }
}
