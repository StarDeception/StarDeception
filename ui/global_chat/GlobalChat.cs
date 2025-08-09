using Godot;
using Godot.Collections;
using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

public partial class GlobalChat : PanelContainer {
    [Export] private LineEdit inputField;
    [Export] private RichTextLabel outputField;
    [Export] private OptionButton channelSelector;
    private bool isVisible = false;

    public override void _Ready() {
        Visible = true;

        string lorem = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?";
        Random random = new Random();
        string[] text_users = new string[] { "NeozSagan", "ddurieu", "irong", "The_Moye" };
        for (int i = 0; i < 30; i++) {
            string user = text_users[random.Next() % text_users.Length];
            channel_E channel = (channel_E)Enum.GetValues(typeof(channel_E)).GetValue(random.Next() % Enum.GetNames(typeof(channel_E)).Length);
            ReceiveMesssageFromServer(lorem.Substr((random.Next() % lorem.Length) / 2, (random.Next() % lorem.Length) / 2), user, channel);
        }

        foreach (string item in Enum.GetNames(typeof(channel_E))) {
            channelSelector.AddItem(item);
            channelSelector.Selected = 0;
        }
    }

    public override void _Process(double delta) {
        if (Input.IsActionJustPressed("toggle_chat")) {
            isVisible = true;
            Visible = isVisible;
        }
        if (isVisible) {
            inputField.GrabFocus();
        } else {
            GetViewport().SetInputAsHandled();
        }
    }

    private void _on_input_text_text_submitted(string nt) {
        if (string.IsNullOrWhiteSpace(nt)) return;
        SendMessageToServer(nt);
        inputField.Text = "";
    }

    void SendMessageToServer(string txt) {
        ReceiveMesssageFromServer(txt, "NeozSagan", Enum.Parse<channel_E>(channelSelector.GetItemText(channelSelector.GetSelectedId())));
    }

    enum channel_E {
        general = 0,
        direct_message = 1,
        group = 2,
        alliance = 3,
        region = 4,
        unspecified = 5,
    }

    private void ReceiveMesssageFromServer(string message, string user_nick, channel_E channel) {
        string gdh = DateTime.Now.Hour.ToString("00") + ":" + DateTime.Now.Minute.ToString("00") + ":" + DateTime.Now.Second.ToString("00");

        outputField.AppendText($"[{gdh}] : [color=#{GetHexaColorFromHash(user_nick)}]{user_nick} [/color][color=#{GetHexaColorFromHash(channel.ToString())}]" +
            $"{(channel == channel_E.unspecified ? "" : ("(" + channel.ToString() + ") "))}{message}[/color]\n");
    }

    Dictionary<string, string> forced_colors = new Dictionary<string, string>() {
        { channel_E.general.ToString(),  "FFFFFF" }
    };
    private string GetHexaColorFromHash(string text) {
        if (forced_colors.ContainsKey(text)) return forced_colors[text];

        byte[] hash = SHA256.Create().ComputeHash(Encoding.UTF8.GetBytes(text));
        string color = BitConverter.ToString(hash).Replace("-", "").Substr(0, 6);
        return color;
    }
}
