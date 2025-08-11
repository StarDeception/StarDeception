using Godot;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

public partial class AutoUpdater : RichTextLabel {
    #region vars
    string repo_url = "https://github.com/StarDeception/StarDeception/releases/download/test/";
    public string exeUrl;
    public string hashUrl;
    public string updaterUrl;
    byte[] hash_bin = new byte[0];
    byte[] bufer_bin = new byte[0];
    long receivedBytes = 0;

    public string expectedHash = ""; // SHA256 localy downloaded
    public string saveHashPath = "user://hash.sha256";
    public string saveExePath = "user://StarDeception.windows.exe";
    public string saveUpdaterPath = "user://SDUpdater.exe";
    RichTextLabel statusLabel;
    [Export] CheckButton hideCheck;
    [Export] RichTextLabel hideLabel;
    [Export] ProgressBar progressBar;
    [Export] Button launchMajButton;
    #endregion

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
            HideLogs();
            return;
        }

        if (OS.HasFeature("linux")) {
            saveUpdaterPath = "user://SDUpdater.sh";
            updaterUrl = repo_url + "SDUpdater.sh";
        }

        //Téléchargement de l'updater
        if (!Godot.FileAccess.FileExists(saveUpdaterPath)) {
            var bytes = await DownloadFromHttp(updaterUrl);
            SaveBinaryOnDisk(saveUpdaterPath, bytes);

            if (OS.HasFeature("linux")) {
                Godot.FileAccess file2 = Godot.FileAccess.Open(saveUpdaterPath, Godot.FileAccess.ModeFlags.Read);
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
    /// download a big file (here only the executable) and get the ability to resume it if failed
    /// </summary>
    /// <param name="url"></param>
    /// <param name="savePath"></param>
    /// <returns></returns>
    public async Task DownloadFileWithProgressAsync(string url, string savePath) {
        try {
            using var client = new System.Net.Http.HttpClient();

            if (bufer_bin.Length != 0) {
                GD.Print("Reprise d'un téléchargement, je possède " + receivedBytes + " octets déjà en mémoire");
                client.DefaultRequestHeaders.Range = new System.Net.Http.Headers.RangeHeaderValue(receivedBytes, null);
            }

            using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);

            response.EnsureSuccessStatusCode();

            long totalBytes = response.Content.Headers.ContentLength ?? -1;
            if (bufer_bin.Length == 0) {
                bufer_bin = new byte[totalBytes];
                receivedBytes = 0;
                GD.Print("Téléchargement d'un nouveau gros fichier" + totalBytes);
            }

            using var contentStream = await response.Content.ReadAsStreamAsync();
            GD.Print("Save large binary file to " + savePath + " > " + ProjectSettings.GlobalizePath(savePath));
            var buffer = new byte[8192];
            int bytesRead;
            int n = 0;
            while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0) {
                if (n % 1000 == 0) {
                    GD.Print("Copie du buffer en pos " + (int)receivedBytes + " = " + ((receivedBytes / (double)bufer_bin.Length) * 100.0) + "%");
                }
                Buffer.BlockCopy(buffer, 0, bufer_bin, (int)receivedBytes, bytesRead);
                receivedBytes += bytesRead;
                if (n % 100 == 0) {
                    progressBar.Value = (receivedBytes / (double)bufer_bin.Length) * 100.0;
                }

                n++;
            }

            GD.Print("Copie sur le disque dur...");
            SaveBinaryOnDisk(savePath, bufer_bin);
            await AfterExeDownloaded();
        } catch (Exception ex) {
            AddLog("Il y a eu un problème lors du téléchargement de l'exe :(" + ex.Message, "FF0000");
            GD.Print(ex.StackTrace);
            AddLog("Tentative de reprise...", "FFFF00");
            await ToSignal(GetTree().CreateTimer(3.0), "timeout");
            await DownloadFileWithProgressAsync(exeUrl, saveExePath);
        }
    }

    /// <summary>
    /// Hide/Show the log text in client
    /// </summary>
    public void HideLogs() {
        statusLabel.Visible = !statusLabel.Visible;
        hideLabel.Text = statusLabel.Visible ? "Masquer les logs de mise à jour" : "Afficher les logs de mise à jour";
    }

    /// <summary>
    /// save a binary file on hard drive
    /// </summary>
    /// <param name="filename"></param>
    /// <param name="bin"></param>
    void SaveBinaryOnDisk(string filename, byte[] bin) {
        var file = Godot.FileAccess.Open(filename, Godot.FileAccess.ModeFlags.Write);
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
    /// check hash.sha256 from github /release and compare to our local version
    /// </summary>
    /// <returns></returns>
    async Task CheckForUpdateAsync() {
        AddLog($"Dossier utilisateur : {ProjectSettings.GlobalizePath("user://")}", "666666");

        //vérification d'un .sha256 déjà présent (maj déjà vérifiée)
        if (Godot.FileAccess.FileExists(saveHashPath)) {
            var file_hash = Godot.FileAccess.Open(saveHashPath, Godot.FileAccess.ModeFlags.Read);
            expectedHash = Encoding.UTF8.GetString(file_hash.GetBuffer((long)file_hash.GetLength()));
            AddLog("Hash en cache : " + expectedHash, "666666");
        } else {
            AddLog("Pas de hash.sha256 en cache, téléchargement...", "FFFF00");
        }

        //requêtte du .sha256 dans /release
        hash_bin = await DownloadFromHttp(hashUrl);
        string hash = Encoding.UTF8.GetString(hash_bin);
        AddLog("Version SHA256 téléchargé : " + hash, "00AAFF");

        if (hash != expectedHash) {
            AddLog("Hash client invalide ! Appuyez sur 'Lancer la mise à jour' :)", "fb7d50");
            launchMajButton.Visible = true;
        } else {
            AddLog("Hash valide :)", "00FF00");
            HideLogs();
        }
    }

    /// <summary>
    /// Start the download of the file
    /// </summary>
    async void StarDownloadExe() {
        if (bufer_bin.Length != 0) {
            AddLog("Une MAJ a déjà été lancée... En cas de souci relancez l'application.", "FFFF00");
            return;
        }
        AddLog("Début de la mise à jour...", "AAFF33");
        await StartDownloadExeTask();
    }

    async Task StartDownloadExeTask() {
        progressBar.Visible = true;
        await DownloadFileWithProgressAsync(exeUrl, saveExePath);
    }

    /// <summary>
    /// Close application and swap executables (downloaded and actual) and relaunch updated executable
    /// </summary>
    /// <returns></returns>
    async Task AfterExeDownloaded() {
        GD.Print("Fichier téléchargé avec succès !");
        progressBar.Visible = false;
        AddLog("Le client va se fermer et se relancer à jour dans 3 secondes...", "22FF33");
        await ToSignal(GetTree().CreateTimer(3.0), "timeout");
        SaveBinaryOnDisk(saveHashPath, hash_bin);
        LaunchUpdater();
    }

    /// <summary>
    /// download a file via http
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
    /// start updater and swap files
    /// </summary>
    void LaunchUpdater() {
        string oldExePath = OS.GetExecutablePath();
        //fermeture exe et auto maj
        if (OS.HasFeature("windows")) {
            if (!Godot.FileAccess.FileExists("user://SDUpdater.exe")) {
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
    /// add a log to chat window
    /// </summary>
    /// <param name="log"></param>
    /// <param name="hexCode"></param>
    void AddLog(string log, string hexCode = "FFFFFF") {
        statusLabel.AppendText($"[color=#{hexCode}]{log}[/color]\n");
    }
}
