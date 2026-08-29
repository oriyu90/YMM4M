using System.Text;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace WpfImeReproducer;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        var app = new Application();
        app.Run(new ImeWindow(args.FirstOrDefault()));
    }
}

public sealed class ImeWindow : Window
{
    private readonly string? outputPath;
    private readonly TextBox input;
    private readonly TextBlock currentValue;
    private readonly TextBox eventLog;

    public ImeWindow(string? outputPath)
    {
        this.outputPath = outputPath;
        Title = "YMM4M WPF IME Reproducer";
        Width = 720;
        Height = 440;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        var root = new Grid { Margin = new Thickness(24) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition());

        var instructions = new TextBlock
        {
            Text = "Click the field, then test ASCII and the macOS Japanese IME.",
            FontSize = 18,
            Margin = new Thickness(0, 0, 0, 14)
        };
        Grid.SetRow(instructions, 0);
        root.Children.Add(instructions);

        input = new TextBox
        {
            Name = "ImeInput",
            FontFamily = new FontFamily("Yu Gothic UI, Noto Sans CJK JP, sans-serif"),
            FontSize = 26,
            MinHeight = 52,
            Padding = new Thickness(8),
            AcceptsReturn = false
        };
        InputMethod.SetIsInputMethodEnabled(input, true);
        InputMethod.SetPreferredImeState(input, InputMethodState.On);
        input.TextChanged += (_, _) => Record("TextChanged", input.Text);
        input.PreviewTextInput += (_, e) => Record("PreviewTextInput", e.Text);
        TextCompositionManager.AddPreviewTextInputStartHandler(input,
            (_, e) => Record("PreviewTextInputStart", e.Text));
        TextCompositionManager.AddPreviewTextInputUpdateHandler(input,
            (_, e) => Record("PreviewTextInputUpdate", e.Text));
        Grid.SetRow(input, 1);
        root.Children.Add(input);

        currentValue = new TextBlock
        {
            Text = "Committed text: (empty)",
            FontSize = 18,
            Margin = new Thickness(0, 14, 0, 14),
            TextWrapping = TextWrapping.Wrap
        };
        Grid.SetRow(currentValue, 2);
        root.Children.Add(currentValue);

        eventLog = new TextBox
        {
            IsReadOnly = true,
            AcceptsReturn = true,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            FontFamily = new FontFamily("Menlo, Consolas, monospace"),
            FontSize = 13
        };
        Grid.SetRow(eventLog, 3);
        root.Children.Add(eventLog);

        Content = root;
        Loaded += (_, _) => input.Focus();
        Record("Started", outputPath ?? "(no output path)");
    }

    private void Record(string eventName, string value)
    {
        if (currentValue is not null)
            currentValue.Text = $"Committed text: {(input.Text.Length == 0 ? "(empty)" : input.Text)}";

        if (eventLog is not null)
        {
            eventLog.AppendText($"{DateTime.UtcNow:O}\t{eventName}\t{Escape(value)}{Environment.NewLine}");
            eventLog.ScrollToEnd();
        }

        if (outputPath is null || input is null)
            return;

        try
        {
            File.WriteAllText(outputPath, input.Text, new UTF8Encoding(false));
            File.AppendAllText(outputPath + ".events.log",
                $"{DateTime.UtcNow:O}\t{eventName}\t{Escape(value)}{Environment.NewLine}",
                new UTF8Encoding(false));
        }
        catch (Exception exception)
        {
            if (eventLog is not null)
                eventLog.AppendText($"OUTPUT ERROR: {exception.GetType().Name}: {exception.Message}{Environment.NewLine}");
        }
    }

    private static string Escape(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
             .Replace("\r", "\\r", StringComparison.Ordinal)
             .Replace("\n", "\\n", StringComparison.Ordinal)
             .Replace("\t", "\\t", StringComparison.Ordinal);
}
