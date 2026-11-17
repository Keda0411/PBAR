$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================

$CurrentDir = $PSScriptRoot
$DefaultJson = Join-Path $CurrentDir "script.json"

$SampleRate = 48000
$Channels = 2
$BitsPerSample = 16
$BytesPerFrame = 4

$Culture = [System.Globalization.CultureInfo]::InvariantCulture
$Ascii = [System.Text.Encoding]::ASCII

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================
# Native Windows folder picker
# ============================================================

if (-not ("NativeFolderPicker" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport]
[Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")]
[ClassInterface(ClassInterfaceType.None)]
public class FileOpenDialogCom
{
}

[ComImport]
[Guid("42F85136-DB7E-439C-85F1-E4075D135FC8")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFileDialog
{
    [PreserveSig] int Show(IntPtr hwndOwner);
    [PreserveSig] int SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
    [PreserveSig] int SetFileTypeIndex(uint iFileType);
    [PreserveSig] int GetFileTypeIndex(out uint piFileType);
    [PreserveSig] int Advise(IntPtr pfde, out uint pdwCookie);
    [PreserveSig] int Unadvise(uint dwCookie);
    [PreserveSig] int SetOptions(uint fos);
    [PreserveSig] int GetOptions(out uint pfos);
    [PreserveSig] int SetDefaultFolder(IShellItem psi);
    [PreserveSig] int SetFolder(IShellItem psi);
    [PreserveSig] int GetFolder(out IShellItem ppsi);
    [PreserveSig] int GetCurrentSelection(out IShellItem ppsi);
    [PreserveSig] int SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    [PreserveSig] int GetFileName(out IntPtr pszName);
    [PreserveSig] int SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
    [PreserveSig] int SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
    [PreserveSig] int SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
    [PreserveSig] int GetResult(out IShellItem ppsi);
    [PreserveSig] int AddPlace(IShellItem psi, uint alignment);
    [PreserveSig] int SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
    [PreserveSig] int Close(int hr);
    [PreserveSig] int SetClientGuid(ref Guid guid);
    [PreserveSig] int ClearClientData();
    [PreserveSig] int SetFilter(IntPtr pFilter);
}

[ComImport]
[Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellItem
{
    [PreserveSig] int BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int GetParent(out IShellItem ppsi);
    [PreserveSig] int GetDisplayName(uint sigdnName, out IntPtr ppszName);
    [PreserveSig] int GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
    [PreserveSig] int Compare(IShellItem psi, uint hint, out int piOrder);
}

public static class NativeFolderPicker
{
    private const uint FOS_OVERWRITEPROMPT = 0x00000002;
    private const uint FOS_NOCHANGEDIR = 0x00000008;
    private const uint FOS_PICKFOLDERS = 0x00000020;
    private const uint FOS_FORCEFILESYSTEM = 0x00000040;
    private const uint FOS_PATHMUSTEXIST = 0x00000800;
    private const uint SIGDN_FILESYSPATH = 0x80058000;

    private const int HRESULT_CANCELLED = unchecked((int)0x800704C7);

    public static string PickFolder(IntPtr owner, string initialPath)
    {
        object dialogObject = null;
        IShellItem resultItem = null;
        IntPtr pathPointer = IntPtr.Zero;

        try
        {
            dialogObject = new FileOpenDialogCom();
            IFileDialog dialog = (IFileDialog)dialogObject;

            uint options;
            int hr = dialog.GetOptions(out options);

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            options |= FOS_PICKFOLDERS |
                       FOS_FORCEFILESYSTEM |
                       FOS_PATHMUSTEXIST |
                       FOS_NOCHANGEDIR;

            hr = dialog.SetOptions(options);

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            hr = dialog.SetTitle("Select output folder");

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            hr = dialog.SetOkButtonLabel("Select folder");

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            // Use the previously selected directory as the initial folder.
            if (!String.IsNullOrWhiteSpace(initialPath) &&
                System.IO.Directory.Exists(initialPath))
            {
                IntPtr shellItemPointer = IntPtr.Zero;

                Guid shellItemGuid = typeof(IShellItem).GUID;

                hr = SHCreateItemFromParsingName(
                    initialPath,
                    IntPtr.Zero,
                    ref shellItemGuid,
                    out shellItemPointer
                );

                if (hr >= 0 && shellItemPointer != IntPtr.Zero)
                {
                    try
                    {
                        IShellItem initialItem =
                            (IShellItem)Marshal.GetObjectForIUnknown(shellItemPointer);

                        dialog.SetFolder(initialItem);

                        Marshal.ReleaseComObject(initialItem);
                    }
                    finally
                    {
                        Marshal.Release(shellItemPointer);
                    }
                }
            }

            hr = dialog.Show(owner);

            if (hr == HRESULT_CANCELLED)
                return null;

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            hr = dialog.GetResult(out resultItem);

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            hr = resultItem.GetDisplayName(
                SIGDN_FILESYSPATH,
                out pathPointer
            );

            if (hr < 0)
                Marshal.ThrowExceptionForHR(hr);

            return Marshal.PtrToStringUni(pathPointer);
        }
        finally
        {
            if (pathPointer != IntPtr.Zero)
                Marshal.FreeCoTaskMem(pathPointer);

            if (resultItem != null)
                Marshal.ReleaseComObject(resultItem);

            if (dialogObject != null && Marshal.IsComObject(dialogObject))
                Marshal.ReleaseComObject(dialogObject);
        }
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
    private static extern int SHCreateItemFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string path,
        IntPtr pbc,
        ref Guid riid,
        out IntPtr ppv
    );
}
'@
}

# ============================================================
# PCM enhancement engine
# ============================================================

if (-not ("PcmEnhancer" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;

public static class PcmEnhancer
{
    public static void Process(
        Stream source,
        Stream destination,
        long byteCount,
        double gainDb,
        double ceilingDb,
        int sampleRate)
    {
        if (byteCount % 4 != 0)
            throw new InvalidDataException("Invalid stereo PCM data size.");

        double gain = Math.Pow(10.0, gainDb / 20.0);
        double ceiling = Math.Pow(10.0, ceilingDb / 20.0);

        if (gain <= 0 || ceiling <= 0 || ceiling > 1.0)
            throw new ArgumentOutOfRangeException("Invalid enhancement parameters.");

        double releaseSeconds = 0.08;
        double releaseCoeff = Math.Exp(-1.0 / (releaseSeconds * sampleRate));
        double envelopeGain = 1.0;

        byte[] buffer = new byte[1024 * 1024];
        long remaining = byteCount;

        while (remaining > 0)
        {
            int count = (int)Math.Min(buffer.Length, remaining);
            count -= count % 4;

            int read = 0;

            while (read < count)
            {
                int n = source.Read(buffer, read, count - read);

                if (n <= 0)
                    throw new EndOfStreamException("Unexpected end of PCM data.");

                read += n;
            }

            for (int i = 0; i < count; i += 4)
            {
                short left = (short)(buffer[i] | (buffer[i + 1] << 8));
                short right = (short)(buffer[i + 2] | (buffer[i + 3] << 8));

                double l = left / 32768.0;
                double r = right / 32768.0;

                double peak = Math.Max(Math.Abs(l), Math.Abs(r)) * gain;
                double targetGain = 1.0;

                if (peak > ceiling)
                    targetGain = ceiling / peak;

                if (targetGain < envelopeGain)
                    envelopeGain = targetGain;
                else
                    envelopeGain = 1.0 - (1.0 - envelopeGain) * releaseCoeff;

                double outL = l * gain * envelopeGain;
                double outR = r * gain * envelopeGain;

                outL = Math.Max(-1.0, Math.Min(1.0, outL));
                outR = Math.Max(-1.0, Math.Min(1.0, outR));

                int sampleL = (int)Math.Round(outL * 32767.0);
                int sampleR = (int)Math.Round(outR * 32767.0);

                sampleL = Math.Max(-32768, Math.Min(32767, sampleL));
                sampleR = Math.Max(-32768, Math.Min(32767, sampleR));

                buffer[i] = (byte)(sampleL & 0xff);
                buffer[i + 1] = (byte)((sampleL >> 8) & 0xff);
                buffer[i + 2] = (byte)(sampleR & 0xff);
                buffer[i + 3] = (byte)((sampleR >> 8) & 0xff);
            }

            destination.Write(buffer, 0, count);
            remaining -= count;
        }
    }
}
'@
}

# ============================================================
# WAV parser
# ============================================================

function Read-WavInfo {
    param([string]$Path)

    $fs = [System.IO.File]::OpenRead($Path)
    $br = New-Object System.IO.BinaryReader($fs)

    try {
        $riff = $Ascii.GetString($br.ReadBytes(4))
        $null = $br.ReadUInt32()
        $wave = $Ascii.GetString($br.ReadBytes(4))

        if ($riff -ne "RIFF" -or $wave -ne "WAVE") {
            throw "Invalid RIFF/WAVE file."
        }

        $fmtBytes = $null
        $dataOffset = -1
        $dataSize = -1

        while ($fs.Position + 8 -le $fs.Length) {
            $chunkId = $Ascii.GetString($br.ReadBytes(4))
            $chunkSize = [long]$br.ReadUInt32()
            $chunkStart = $fs.Position

            if ($chunkStart + $chunkSize -gt $fs.Length) {
                throw "Invalid WAV chunk size."
            }

            if ($chunkId -eq "fmt ") {
                if ($chunkSize -lt 16) {
                    throw "Invalid WAV format chunk."
                }

                $fmtBytes = $br.ReadBytes([int]$chunkSize)
            }
            elseif ($chunkId -eq "data") {
                if ($dataOffset -ne -1) {
                    throw "Multiple data chunks are not supported."
                }

                $dataOffset = $chunkStart
                $dataSize = $chunkSize
            }

            $fs.Position = $chunkStart + $chunkSize + ($chunkSize % 2)
        }

        if ($null -eq $fmtBytes -or $dataOffset -lt 0) {
            throw "WAV format or data chunk not found."
        }

        $audioFormat = [BitConverter]::ToUInt16($fmtBytes, 0)
        $channels = [BitConverter]::ToUInt16($fmtBytes, 2)
        $sampleRate = [BitConverter]::ToUInt32($fmtBytes, 4)
        $blockAlign = [BitConverter]::ToUInt16($fmtBytes, 12)
        $bits = [BitConverter]::ToUInt16($fmtBytes, 14)

        if ($audioFormat -ne 1) {
            throw "Only PCM WAV is supported."
        }

        if ($channels -ne $Channels) {
            throw "Expected stereo WAV (2 channels), found $channels."
        }

        if ($sampleRate -ne $SampleRate) {
            throw "Expected 48000 Hz, found $sampleRate Hz."
        }

        if ($bits -ne $BitsPerSample) {
            throw "Expected 16-bit WAV, found $bits-bit."
        }

        if ($blockAlign -ne $BytesPerFrame) {
            throw "Unexpected WAV block alignment."
        }

        if (($dataSize % $BytesPerFrame) -ne 0) {
            throw "WAV data is not aligned to complete sample frames."
        }

        return [PSCustomObject]@{
            FormatBytes = $fmtBytes
            DataOffset = $dataOffset
            DataSize = $dataSize
            TotalFrames = [long]($dataSize / $BytesPerFrame)
        }
    }
    finally {
        $br.Dispose()
    }
}

# ============================================================
# WAV writer
# ============================================================

function Write-WavHeader {
    param(
        [System.IO.BinaryWriter]$Writer,
        [byte[]]$FormatBytes,
        [long]$DataSize
    )

    $fmtSize = $FormatBytes.Length
    $fmtPadding = $fmtSize % 2
    $riffSize = 4 + 8 + $fmtSize + $fmtPadding + 8 + $DataSize

    if ($riffSize -gt [uint32]::MaxValue) {
        throw "Output file exceeds standard WAV size limit."
    }

    $Writer.Write($Ascii.GetBytes("RIFF"))
    $Writer.Write([uint32]$riffSize)
    $Writer.Write($Ascii.GetBytes("WAVE"))

    $Writer.Write($Ascii.GetBytes("fmt "))
    $Writer.Write([uint32]$fmtSize)
    $Writer.Write($FormatBytes)

    if ($fmtPadding) {
        $Writer.Write([byte]0)
    }

    $Writer.Write($Ascii.GetBytes("data"))
    $Writer.Write([uint32]$DataSize)
}

# ============================================================
# WAV segment exporter
# ============================================================

function Export-WavSegment {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [byte[]]$FormatBytes,
        [long]$DataOffset,
        [long]$StartFrame,
        [long]$EndFrame,
        [double]$GainDb,
        [double]$CeilingDb
    )

    $frameCount = $EndFrame - $StartFrame

    if ($frameCount -le 0) {
        throw "Invalid segment length."
    }

    $dataSize = $frameCount * $BytesPerFrame

    if ($dataSize -gt [uint32]::MaxValue) {
        throw "Output file exceeds standard WAV size limit."
    }

    $source = [System.IO.File]::OpenRead($SourcePath)
    $destination = [System.IO.File]::Create($DestinationPath)
    $writer = New-Object System.IO.BinaryWriter($destination)

    try {
        Write-WavHeader `
            -Writer $writer `
            -FormatBytes $FormatBytes `
            -DataSize $dataSize

        $source.Position = $DataOffset + ($StartFrame * $BytesPerFrame)

        [PcmEnhancer]::Process(
            $source,
            $destination,
            $dataSize,
            $GainDb,
            $CeilingDb,
            $SampleRate
        )
    }
    finally {
        $writer.Dispose()
        $source.Dispose()
    }
}

# ============================================================
# Create enhanced temporary WAV for preview
# ============================================================

function New-PreviewWav {
    param(
        [string]$SourcePath,
        [object]$Info,
        [double]$GainDb,
        [double]$CeilingDb
    )

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) (
        "PBARPreview_{0}.wav" -f [guid]::NewGuid().ToString("N")
    )

    $source = [System.IO.File]::OpenRead($SourcePath)
    $destination = [System.IO.File]::Create($tempPath)
    $writer = New-Object System.IO.BinaryWriter($destination)

    try {
        Write-WavHeader `
            -Writer $writer `
            -FormatBytes $Info.FormatBytes `
            -DataSize $Info.DataSize

        $source.Position = $Info.DataOffset

        [PcmEnhancer]::Process(
            $source,
            $destination,
            $Info.DataSize,
            $GainDb,
            $CeilingDb,
            $SampleRate
        )
    }
    catch {
        $writer.Dispose()
        $source.Dispose()

        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }

        throw
    }

    $writer.Dispose()
    $source.Dispose()

    return $tempPath
}

# ============================================================
# Main window
# ============================================================

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PBAR"
        Width="760"
        SizeToContent="Height"
        MinWidth="680"
        MinHeight="480"
        WindowStartupLocation="CenterScreen"
        Background="#F4F5F7"
        FontFamily="Segoe UI">

    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0"
                   Text="PBAR"
                   FontSize="25"
                   FontWeight="SemiBold"
                   Margin="0,0,0,20"/>

        <GroupBox Grid.Row="1" Header="Script" Padding="14" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="48"/><ColumnDefinition Width="*"/><ColumnDefinition Width="90"/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="34"/><RowDefinition Height="38"/></Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="Paks Dir" VerticalAlignment="Center"/>
                <TextBox x:Name="PaksPathBox" Grid.Row="0" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center" HorizontalAlignment="Stretch"/>
                <Button x:Name="BrowsePaksButton" Grid.Row="0" Grid.Column="2" Content="Browse..." Width="80" VerticalAlignment="Stretch" Margin="5,2"/>
                <TextBlock Grid.Row="1" Text="Cli Dir" VerticalAlignment="Center"/>
                <TextBox x:Name="CliPathBox" Grid.Row="1" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center" HorizontalAlignment="Stretch"/>
                <Button x:Name="BrowseCliButton" Grid.Row="1" Grid.Column="2" Content="Browse..." Width="80" VerticalAlignment="Stretch" Margin="5,2"/>
                <TextBlock Grid.Row="2" Text="Json Dir" VerticalAlignment="Center"/>
                <TextBox x:Name="JsonPathBox" Grid.Row="2" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center" HorizontalAlignment="Stretch"/>
                <Button x:Name="BrowseJsonButton" Grid.Row="2" Grid.Column="2" Content="Browse..." Width="80" VerticalAlignment="Stretch" Margin="5,2"/>
                <Button x:Name="GenerateJsonButton" Grid.Row="3" Grid.ColumnSpan="3" Content="Generate / Update script.json" Margin="5,3,5,0"/>
                <ProgressBar x:Name="JsonProgressBar" Grid.Row="3" Grid.ColumnSpan="3" Minimum="0" Maximum="1" Value="0" Visibility="Collapsed" Margin="5,3,5,0"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="3" Header="Audio" Padding="14" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="90"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="40"/>
                </Grid.RowDefinitions>

                <TextBox x:Name="WavPathBox" Grid.Row="0" Grid.Column="0"
                         VerticalContentAlignment="Center" Margin="5,3,5,0"/>
                <Button x:Name="BrowseWavButton" Grid.Row="0" Grid.Column="1"
                        Content="Browse..." Width="80" VerticalAlignment="Stretch" Margin="5,3,5,0"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="2" Header="Sequence" Padding="14" Margin="0,0,0,14">
            <Grid>
                <ComboBox x:Name="SequenceBox"
                          Height="34" VerticalContentAlignment="Center"
                          DisplayMemberPath="DisplayName"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="4" Header="Trim Range" Padding="14" Margin="0,0,0,14">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="42"/>
                    <RowDefinition Height="42"/>
                    <RowDefinition Height="20"/>
                </Grid.RowDefinitions>

                <Slider x:Name="ProgressSlider"
                        Grid.Row="0"
                        Minimum="0"
                        Maximum="1"
                        Value="0"
                        IsMoveToPointEnabled="False"
                        IsEnabled="False"
                        VerticalAlignment="Center"
                        Margin="5,0"/>

                <Grid Grid.Row="1" Margin="4,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.3*"/>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="1.3*"/>
                    </Grid.ColumnDefinitions>

                    <TextBox x:Name="StartBox" Grid.Column="0"
                             Height="32" FontSize="14"
                             VerticalContentAlignment="Center"
                             HorizontalContentAlignment="Center"
                             Text="--:--:--"
                             ToolTip="Start time (HH:MM:SS). Press Enter or leave the field to apply."/>

                    <Button x:Name="PlayButton" Grid.Column="1"
                            Content="Play" Height="32" Margin="3,0"/>

                    <Button x:Name="LoopButton" Grid.Column="2"
                            Content="Loop" Height="32" Margin="3,0"/>

                    <Button x:Name="PauseButton" Grid.Column="1" Grid.ColumnSpan="2"
                            Content="Pause" Height="32" Margin="3,0" Visibility="Collapsed"/>

                    <TextBox x:Name="EndBox" Grid.Column="3"
                             Height="32" FontSize="14"
                             VerticalContentAlignment="Center"
                             HorizontalContentAlignment="Center"
                             ToolTip="End time (HH:MM:SS). Press Enter or leave the field to apply."/>
                </Grid>

                <Grid Grid.Row="2" Margin="4,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock x:Name="CurrentTimeText"
                               Text="00:00:00"
                               VerticalAlignment="Bottom"/>

                    <TextBlock x:Name="TotalTimeText"
                               Grid.Column="1"
                               Text="00:00:00"
                               HorizontalAlignment="Right"
                               VerticalAlignment="Bottom"/>
                </Grid>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="5" Header="Audio Enhancement" Padding="14" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="110"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="75"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="42"/>
                    <RowDefinition Height="30"/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row="0" Text="Gain" VerticalAlignment="Center"/>
                <Slider x:Name="GainSlider" Grid.Row="0" Grid.Column="1"
                        Minimum="0" Maximum="18" Value="6"
                        TickFrequency="1" IsSnapToTickEnabled="False"
                        VerticalAlignment="Center" Margin="8,0"/>
                <TextBlock x:Name="GainValueText" Grid.Row="0" Grid.Column="2"
                           Text="+6.0 dB" VerticalAlignment="Center"
                           HorizontalAlignment="Right"/>

                <TextBlock Grid.Row="1" Text="Limiter ceiling" VerticalAlignment="Center"/>
                <ComboBox x:Name="CeilingBox" Grid.Row="1" Grid.Column="1"
                          Grid.ColumnSpan="2" Height="30"
                          VerticalContentAlignment="Center">
                    <ComboBoxItem Content="-0.5 dBFS" Tag="-0.5"/>
                    <ComboBoxItem Content="-1.0 dBFS" Tag="-1.0" IsSelected="True"/>
                    <ComboBoxItem Content="-2.0 dBFS" Tag="-2.0"/>
                    <ComboBoxItem Content="-3.0 dBFS" Tag="-3.0"/>
                </ComboBox>

            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="6" Header="Export" Padding="14" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="90"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="42"/>
                    <RowDefinition Height="43"/>
                </Grid.RowDefinitions>

                <TextBox x:Name="OutputBox" Grid.Row="0" Grid.Column="0"
                         VerticalContentAlignment="Center" Margin="5,3,5,0"/>
                <Button x:Name="BrowseOutputButton" Grid.Row="0" Grid.Column="1"
                        Content="Browse..." Width="80" VerticalAlignment="Stretch" Margin="5,3,5,0"/>

                <Button x:Name="ExportButton" Grid.Row="1" Grid.Column="0"
                        Grid.ColumnSpan="3" Content="Cut and Export"
                        Height="38" Margin="5,5,5,0"/>
            </Grid>
        </GroupBox>

        <TextBlock Grid.Row="7"
                   Text="WAV: PCM 16-bit / 48 kHz / Stereo"
                   Foreground="#777777"
                   FontSize="11"
                   VerticalAlignment="Center"/>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# ============================================================
# Get controls
# ============================================================

$WavPathBox = $window.FindName("WavPathBox")
$OutputBox = $window.FindName("OutputBox")
$JsonPathBox = $window.FindName("JsonPathBox")
$CliPathBox = $window.FindName("CliPathBox")
$PaksPathBox = $window.FindName("PaksPathBox")
$BrowseJsonButton = $window.FindName("BrowseJsonButton")
$BrowseCliButton = $window.FindName("BrowseCliButton")
$BrowsePaksButton = $window.FindName("BrowsePaksButton")
$GenerateJsonButton = $window.FindName("GenerateJsonButton")
$JsonProgressBar = $window.FindName("JsonProgressBar")

$BrowseWavButton = $window.FindName("BrowseWavButton")
$BrowseOutputButton = $window.FindName("BrowseOutputButton")

$SequenceBox = $window.FindName("SequenceBox")
$StartBox = $window.FindName("StartBox")
$EndBox = $window.FindName("EndBox")

$PlayButton = $window.FindName("PlayButton")
$LoopButton = $window.FindName("LoopButton")
$PauseButton = $window.FindName("PauseButton")
$ExportButton = $window.FindName("ExportButton")

$ProgressSlider = $window.FindName("ProgressSlider")
$CurrentTimeText = $window.FindName("CurrentTimeText")
$TotalTimeText = $window.FindName("TotalTimeText")

$GainSlider = $window.FindName("GainSlider")
$GainValueText = $window.FindName("GainValueText")
$CeilingBox = $window.FindName("CeilingBox")

# ============================================================
# MediaPlayer and state
# ============================================================

$script:Player = New-Object System.Windows.Media.MediaPlayer
$script:Player.Volume = 1.0

$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(50)

$script:Sequences = @()
$script:MediaReady = $false
$script:OpeningMedia = $false
$script:MediaPath = ""
$script:PreviewPath = ""
$script:PreviewParameterKey = ""
$script:PreviewGenerating = $false
$script:PreviewPowerShell = $null
$script:PreviewHandle = $null
$script:PreviewSync = $null

$script:WavInfo = $null
$script:TotalDuration = 0.0

$script:PendingStart = 0.0
$script:PendingEnd = 0.0

$script:PlaybackActive = $false
$script:PlaybackMode = "Sequence"
$script:PendingPlaybackPosition = $null
$script:PendingPreviewStart = 0.0
$script:PendingPreviewEnd = 0.0
$script:StartInputDirty = $false
$script:EndInputDirty = $false
$script:UpdatingTimeFields = $false
$script:UserSeeking = $false
$script:UpdatingSlider = $false
$script:LastStatus = ""

$JsonPathBox.Text = ""
$CliPathBox.Text = "D:\UEBulkExport\UEBulkExport.Cli.exe"
$PaksPathBox.Text = "D:\Steam\steamapps\common\StellarBlade\SB\Content\Paks"
$WavPathBox.Text = ""
$OutputBox.Text = "D:\Steam\steamapps\common\StellarBlade\SB\Content\Paks\LogicMods\HD-ATOOL_P\audio"

# ============================================================
# Helper functions
# ============================================================

function Set-Status {
    param([string]$Message)

    $script:LastStatus = $Message
}

function Format-Time {
    param([double]$Seconds)
    $totalSeconds = [long][Math]::Floor([Math]::Max(0, $Seconds))
    $hours = [long][Math]::Floor($totalSeconds / 3600)
    $minutes = [int][Math]::Floor(($totalSeconds % 3600) / 60)
    $remainingSeconds = [int]($totalSeconds % 60)
    return "{0:00}:{1:00}:{2:00}" -f $hours, $minutes, $remainingSeconds
}

function Parse-Time {
    param([string]$Text)

    $value = $Text.Trim()

    if ($value -notmatch '^(\d+):([0-5]\d):([0-5]\d)$') {
        throw "Invalid time format. Use HH:MM:SS, for example 00:01:23."
    }

    $hours = [double]$Matches[1]
    $minutes = [double]$Matches[2]
    $seconds = [double]$Matches[3]
    return ($hours * 3600) + ($minutes * 60) + $seconds
}

function Get-SelectedSequence {
    if ($null -eq $SequenceBox.SelectedItem) {
        throw "Please select a sequence."
    }

    return $SequenceBox.SelectedItem.Sequence
}

function Get-SequenceDuration {
    $sequence = Get-SelectedSequence
    $duration = [double]$sequence.duration

    if ([double]::IsNaN($duration) -or
        [double]::IsInfinity($duration) -or
        $duration -le 0) {
        throw "Invalid sequence duration."
    }

    return $duration
}

function Get-PartClipId {
    param($Part, [string]$Context)

    if ($Part -is [System.ValueType]) {
        $value = $Part
    }
    else {
        $clipProperty = $Part.PSObject.Properties["clip"]
        if ($null -eq $clipProperty) { throw "Missing clip property in $Context." }
        $value = $clipProperty.Value
    }

    $text = [Convert]::ToString($value, $Culture)
    if ($text -notmatch '^\d+$') { throw "Invalid clip ID in ${Context}: $text" }
    return [long]$text
}

function Format-ErrorMessage {
    param([string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) { return "An Unknown Error Occurred." }
    return $Message.Substring(0, 1).ToUpperInvariant() + $Message.Substring(1)
}

function Find-SequenceLength {
    param($Node, [System.Collections.Generic.List[object]]$Matches)

    if ($null -eq $Node -or $Node -is [string] -or $Node -is [System.ValueType]) { return }
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [System.Collections.IDictionary]) {
        foreach ($item in $Node) { Find-SequenceLength $item $Matches }
        return
    }
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            if ([string]$key -eq "SequenceLength") { $Matches.Add($Node[$key]) }
            else { Find-SequenceLength $Node[$key] $Matches }
        }
        return
    }
    foreach ($property in $Node.PSObject.Properties) {
        if ($property.Name -eq "SequenceLength") { $Matches.Add($property.Value) }
        else { Find-SequenceLength $property.Value $Matches }
    }
}

function Get-ClipDuration {
    param([string]$FilePath, [long]$ClipId)

    $json = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $matches = New-Object 'System.Collections.Generic.List[object]'
    Find-SequenceLength $json $matches
    if ($matches.Count -ne 1) { throw "Clip ${ClipId}: expected exactly one SequenceLength." }

    $duration = [double]$matches[0]
    if ([double]::IsNaN($duration) -or [double]::IsInfinity($duration) -or $duration -le 0) {
        throw "Clip ${ClipId}: invalid SequenceLength."
    }
    return $duration
}

function Update-JsonProgress {
    param([int]$Completed, [int]$Total)

    $JsonProgressBar.Maximum = [Math]::Max(1, $Total)
    $JsonProgressBar.Value = [Math]::Min($Completed, $JsonProgressBar.Maximum)
    [System.Windows.Forms.Application]::DoEvents()
}

function Remove-GenerationArtifacts {
    foreach ($fileName in @("UEBulkExport.log", "_completed.json.txt")) {
        $filePath = Join-Path $PSScriptRoot $fileName
        if (Test-Path -LiteralPath $filePath -PathType Leaf) {
            Remove-Item -LiteralPath $filePath -Force
        }
    }

    $sbDirectory = Join-Path $PSScriptRoot "SB"
    $contentDirectory = Join-Path $sbDirectory "Content"
    if (Test-Path -LiteralPath $sbDirectory -PathType Container) {
        $otherDirectories = @(Get-ChildItem -LiteralPath $sbDirectory -Directory -Force |
            Where-Object { $_.Name -ne "Content" })

        if ($otherDirectories.Count -eq 0) {
            Remove-Item -LiteralPath $sbDirectory -Recurse -Force
        }
        elseif (Test-Path -LiteralPath $contentDirectory -PathType Container) {
            Remove-Item -LiteralPath $contentDirectory -Recurse -Force
        }
    }
}

function Generate-ScriptJson {
    $source = Get-Content -LiteralPath $JsonPathBox.Text.Trim() -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $source.sequences -or $source.sequences.Count -eq 0) { throw "No sequences found in ATOOL JSON." }

    $sequenceDefinitions = @()
    $clips = [System.Collections.Generic.List[long]]::new()
    $clipSet = @{}
    foreach ($sequence in $source.sequences) {
        if ([string]::IsNullOrWhiteSpace([string]$sequence.name) -or $sequence.parts.Count -eq 0) {
            throw "Invalid sequence definition in ATOOL JSON."
        }

        $parts = @()
        foreach ($part in $sequence.parts) {
            $clip = Get-PartClipId $part "sequence '$($sequence.name)'"
            $loops = if ($null -eq $part.loops) { 1 } else { [int]$part.loops }
            if ($loops -lt 1) { throw "Invalid loop count for clip $clip." }
            $parts += [PSCustomObject]@{ Clip = $clip; Loops = $loops }
            if (-not $clipSet.ContainsKey([string]$clip)) {
                $clipSet[[string]$clip] = $true
                $clips.Add($clip)
            }
        }
        $sequenceDefinitions += [PSCustomObject]@{ Name = [string]$sequence.name; Parts = $parts }
    }

    $animAssetPath = "SB/Content/Mods/HD-ATOOL_P/anim"
    $animJsonDirectory = Join-Path $PSScriptRoot "SB\Content\Mods\HD-ATOOL_P\anim"
    Update-JsonProgress -Completed 0 -Total $clips.Count
    $completed = 0
    foreach ($clip in $clips) {
        $asset = "$animAssetPath/$clip.uasset"
        & $CliPathBox.Text.Trim() --paks $PaksPathBox.Text.Trim() --out $PSScriptRoot --mode json --game GAME_UE4_26 --include $asset
        if ($LASTEXITCODE -ne 0) { throw "Failed to export animation $clip." }
        $completed++
        Update-JsonProgress -Completed $completed -Total $clips.Count
    }

    $finalSequences = @()
    foreach ($sequence in $sequenceDefinitions) {
        $cursor = 0.0
        $finalParts = @()
        foreach ($part in $sequence.Parts) {
            $duration = Get-ClipDuration (Join-Path $animJsonDirectory "$($part.Clip).json") $part.Clip
            $end = $cursor + ($duration * $part.Loops)
            $finalParts += [ordered]@{
                clip = $part.Clip
                loops = $part.Loops
                duration = $duration
                start = $cursor
                end = $end
            }
            $cursor = $end
        }
        $finalSequences += [ordered]@{ name = $sequence.Name; duration = $cursor; parts = $finalParts }
    }

    [ordered]@{ sequences = $finalSequences } |
        ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $DefaultJson -Encoding UTF8

    Remove-GenerationArtifacts
}

function Get-StartTime {
    return Parse-Time $StartBox.Text
}

function Get-EndTime {
    return Parse-Time $EndBox.Text
}

function Get-GainDb {
    return [double]$GainSlider.Value
}

function Get-CeilingDb {
    $item = $CeilingBox.SelectedItem

    if ($null -eq $item) {
        throw "Please select a limiter ceiling."
    }

    return [double]$item.Tag
}

function Remove-PreviewFile {
    if (-not [string]::IsNullOrWhiteSpace($script:PreviewPath)) {
        try {
            if (Test-Path -LiteralPath $script:PreviewPath) {
                Remove-Item -LiteralPath $script:PreviewPath -Force
            }
        }
        catch {
        }

        $script:PreviewPath = ""
        $script:PreviewParameterKey = ""
    }
}

function Pause-Playback {
    if ($script:MediaReady) {
        $script:Player.Pause()
    }

    $script:Timer.Stop()
    $script:PlaybackActive = $false
    $PlayButton.Visibility = [System.Windows.Visibility]::Visible
    $LoopButton.Visibility = [System.Windows.Visibility]::Visible
    $PauseButton.Visibility = [System.Windows.Visibility]::Collapsed
}

function Set-StartPosition {
    param(
        [double]$Start,
        [bool]$Seek = $true,
        [Nullable[double]]$ExactEnd = $null
    )

    $duration = Get-SequenceDuration

    if ($script:TotalDuration -gt 0) {
        $duration = [Math]::Min($duration, $script:TotalDuration)
    }

    if ($Start -lt 0) {
        $Start = 0
    }

    if ($script:TotalDuration -gt 0) {
        $maxStart = $script:TotalDuration - $duration
        if ($Start -gt $maxStart) {
            $Start = $maxStart
        }
    }

    if ($null -ne $ExactEnd) {
        $end = [double]$ExactEnd
        if ($script:TotalDuration -gt 0 -and $end -gt $script:TotalDuration) {
            $end = $script:TotalDuration
        }
        $Start = $end - $duration
        if ($Start -lt 0) {
            $Start = 0
            $end = [Math]::Min($duration, $script:TotalDuration)
        }
    }
    else {
        $end = $Start + $duration
    }

    $script:PendingStart = $Start
    $script:PendingEnd = $end

    $script:UpdatingTimeFields = $true
    try {
        $StartBox.Text = Format-Time $Start
        $EndBox.Text = Format-Time $end
    }
    finally {
        $script:UpdatingTimeFields = $false
    }

    if ($Seek -and $script:MediaReady) {
        $script:Player.Position = [TimeSpan]::FromSeconds($Start)
    }

    $CurrentTimeText.Text = Format-Time $Start

    return @{
        Start = $Start
        End = $end
    }
}

function Update-RangeFromInput {
    $start = Get-StartTime
    return Set-StartPosition -Start $start -Seek $true
}

function Update-EndFromInput {
    $end = Get-EndTime
    $start = $end - (Get-SequenceDuration)
    $range = Set-StartPosition -Start $start -Seek $true -ExactEnd $end
    return $range
}

function Update-ProgressDisplay {
    if (-not $script:MediaReady) {
        return
    }

    $position = $script:Player.Position.TotalSeconds
    $position = [Math]::Max(0, [Math]::Min(
        $position,
        $script:TotalDuration
    ))

    if (-not $script:UserSeeking) {
        $script:UpdatingSlider = $true

        try {
            $ProgressSlider.Value = $position
        }
        finally {
            $script:UpdatingSlider = $false
        }
    }

    $CurrentTimeText.Text = Format-Time $position
}

function Set-SelectedStart {
    param([double]$Start)

    Pause-Playback

    $range = Set-StartPosition -Start $Start -Seek $true

    $script:UpdatingSlider = $true

    try {
        $ProgressSlider.Value = $range.Start
    }
    finally {
        $script:UpdatingSlider = $false
    }

    Set-Status "Start position updated."

    return $range
}

function Load-Sequences {
    $path = $DefaultJson

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "script.json not found in the application folder: $path"
    }

    $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 |
        ConvertFrom-Json

    $items = @($json.sequences)

    if ($items.Count -eq 0) {
        throw "No sequences found in JSON."
    }

    $SequenceBox.Items.Clear()
    $script:Sequences = $items

    foreach ($seq in $items) {
        $entry = [PSCustomObject]@{
            DisplayName = "{0} ({1:N2}s)" -f $seq.name, [double]$seq.duration
            Sequence = $seq
        }

        $SequenceBox.Items.Add($entry) | Out-Null
    }

    $SequenceBox.SelectedIndex = 0
}

$BrowseJsonButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    if ($dialog.ShowDialog()) { $JsonPathBox.Text = $dialog.FileName }
})

$BrowseCliButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
    if ($dialog.ShowDialog()) { $CliPathBox.Text = $dialog.FileName }
})

$BrowsePaksButton.Add_Click({
    $selectedPath = [NativeFolderPicker]::PickFolder(
        [System.Windows.Interop.WindowInteropHelper]::new($window).Handle,
        $PaksPathBox.Text.Trim()
    )
    if ($selectedPath) { $PaksPathBox.Text = $selectedPath }
})

$GenerateJsonButton.Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $JsonPathBox.Text.Trim() -PathType Leaf)) { throw "Select a valid ATOOL JSON file." }
        if (-not (Test-Path -LiteralPath $CliPathBox.Text.Trim() -PathType Leaf)) { throw "Select a valid UEBulk CLI executable." }
        if (-not (Test-Path -LiteralPath $PaksPathBox.Text.Trim() -PathType Container)) { throw "Select a valid Paks folder." }
        $GenerateJsonButton.IsEnabled = $false
        $GenerateJsonButton.Visibility = [System.Windows.Visibility]::Collapsed
        $JsonProgressBar.Visibility = [System.Windows.Visibility]::Visible
        $JsonProgressBar.Value = 0
        Set-Status "Generating script.json..."
        Generate-ScriptJson
        Load-Sequences
        Set-Status "script.json generated and loaded."
        $JsonProgressBar.Value = $JsonProgressBar.Maximum
        [System.Windows.MessageBox]::Show(
            "Success.",
            "Generation Complete",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
    catch {
        [System.Windows.MessageBox]::Show(
            (Format-ErrorMessage $_.Exception.Message),
            "Generation Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        Set-Status ("Generation error: {0}" -f $_.Exception.Message)
    }
    finally {
        $JsonProgressBar.Visibility = [System.Windows.Visibility]::Collapsed
        $GenerateJsonButton.Visibility = [System.Windows.Visibility]::Visible
        $GenerateJsonButton.IsEnabled = $true
    }
})

function Start-Playback {
    if (-not $script:MediaReady) {
        return
    }

    if ($script:PlaybackMode -eq "Sequence") {
        $script:Player.Position = [TimeSpan]::FromSeconds($script:PendingStart)
    }
    elseif ($null -ne $script:PendingPlaybackPosition) {
        $resumePosition = [Math]::Max(0, [Math]::Min([double]$script:PendingPlaybackPosition, $script:TotalDuration))
        $script:Player.Position = [TimeSpan]::FromSeconds($resumePosition)
        $script:PendingPlaybackPosition = $null
    }
    else {
        $position = $script:Player.Position.TotalSeconds
        if ($position -lt $script:PendingStart -or $position -ge $script:TotalDuration) {
            $script:Player.Position = [TimeSpan]::FromSeconds($script:PendingStart)
        }
    }

    if ($script:PlaybackMode -eq "Sequence") {
        Set-Status ("Playing sequence: {0} - {1}" -f `
            (Format-Time $script:PendingStart),
            (Format-Time $script:PendingEnd))
    }
    else {
        Set-Status "Playing full audio."
    }

    $script:Player.Play()
    $script:PlaybackActive = $true
    $script:Timer.Start()
    $PlayButton.Visibility = [System.Windows.Visibility]::Collapsed
    $LoopButton.Visibility = [System.Windows.Visibility]::Collapsed
    $PauseButton.Visibility = [System.Windows.Visibility]::Visible
}

function Adjust-Start {
    param([double]$Delta)

    try {
        $start = Get-StartTime
        Set-SelectedStart ($start + $Delta) | Out-Null
    }
    catch {
        [System.Windows.MessageBox]::Show(
            (Format-ErrorMessage $_.Exception.Message),
            "Invalid Start Time",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

# ============================================================
# Slider visual helpers
# ============================================================

function Find-VisualAncestor {
    param(
        [System.Windows.DependencyObject]$Element,
        [type]$TargetType
    )

    $current = $Element

    while ($null -ne $current) {
        if ($TargetType.IsInstanceOfType($current)) {
            return $current
        }

        try {
            $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
        }
        catch {
            return $null
        }
    }

    return $null
}

function Get-SliderValueFromTrackPoint {
    param(
        [System.Windows.Controls.Primitives.Track]$Track,
        [System.Windows.Input.MouseButtonEventArgs]$EventArgs
    )

    $point = $EventArgs.GetPosition($Track)
    return [double]$Track.ValueFromPoint($point)
}

# ============================================================
# Playback timer
# ============================================================

$script:Timer.Add_Tick({
    if ($script:PreviewGenerating) {
        if ($null -eq $script:PreviewHandle -or -not $script:PreviewHandle.IsCompleted) {
            return
        }

        try {
            $script:PreviewPowerShell.EndInvoke($script:PreviewHandle) | Out-Null
        }
        catch {
            $script:PreviewSync.Error = $_.Exception.Message
        }
        finally {
            $script:PreviewPowerShell.Dispose()
            $script:PreviewPowerShell = $null
            $script:PreviewHandle = $null
            $script:PreviewGenerating = $false
        }

        if (-not [string]::IsNullOrWhiteSpace($script:PreviewSync.Error)) {
            $script:OpeningMedia = $false
            Set-Status ("Preview generation failed: {0}" -f $script:PreviewSync.Error)
            [System.Windows.MessageBox]::Show($script:PreviewSync.Error, "Preview error") | Out-Null
            return
        }

        $script:PreviewPath = $script:PreviewSync.Path
        $script:PendingStart = $script:PendingPreviewStart
        $script:PendingEnd = $script:PendingPreviewEnd
        $script:OpeningMedia = $true
        $ProgressSlider.IsEnabled = $true
        $ProgressSlider.Maximum = $script:TotalDuration
        $TotalTimeText.Text = Format-Time $script:TotalDuration
        $script:Player.Open([System.Uri]::new([System.IO.Path]::GetFullPath($script:PreviewPath)))
        Set-Status "Loading enhanced preview..."
        return
    }

    if (-not $script:PlaybackActive) {
        $script:Timer.Stop()
        return
    }

    try {
        $position = $script:Player.Position.TotalSeconds

        $playbackEnd = $script:TotalDuration
        if ($script:PlaybackMode -eq "Sequence") {
            $playbackEnd = $script:PendingEnd
        }

        if ($position -ge $playbackEnd) {
            if ($script:PlaybackMode -eq "Sequence") {
                $script:Player.Position = [TimeSpan]::FromSeconds($script:PendingStart)
                $script:Player.Play()
                Update-ProgressDisplay
            }
            else {
                $script:Player.Pause()
                $script:Player.Position = [TimeSpan]::FromSeconds($playbackEnd)
                Pause-Playback
                Update-ProgressDisplay
                Set-Status "Full audio playback completed."
                return
            }
        }

        Update-ProgressDisplay
    }
    catch {
        Pause-Playback
        Set-Status ("Playback error: {0}" -f $_.Exception.Message)
    }
})

# ============================================================
# MediaPlayer events
# ============================================================

$script:Player.Add_MediaOpened({
    try {
        $script:MediaReady = $true
        $script:OpeningMedia = $false

        if ($script:Player.NaturalDuration.HasTimeSpan) {
            $script:TotalDuration = $script:Player.NaturalDuration.TimeSpan.TotalSeconds
        }
        else {
            throw "Unable to determine audio duration."
        }

        $ProgressSlider.Minimum = 0
        $ProgressSlider.Maximum = $script:TotalDuration
        $ProgressSlider.IsEnabled = $true

        $TotalTimeText.Text = Format-Time $script:TotalDuration

        if ($script:PlaybackMode -eq "Sequence") {
            Set-StartPosition -Start $script:PendingStart -Seek $true | Out-Null
        }
        elseif ($null -eq $script:PendingPlaybackPosition) {
            $script:PendingPlaybackPosition = $script:PendingStart
        }

        $script:UpdatingSlider = $true

        try {
            $ProgressSlider.Value = $script:PendingStart
        }
        finally {
            $script:UpdatingSlider = $false
        }

        Start-Playback
    }
    catch {
        $script:MediaReady = $false
        $script:OpeningMedia = $false
        Pause-Playback
        Set-Status ("Playback error: {0}" -f $_.Exception.Message)
    }
})

$script:Player.Add_MediaFailed({
    param($sender, $eventArgs)

    $script:MediaReady = $false
    $script:OpeningMedia = $false
    $script:PlaybackActive = $false
    $script:Timer.Stop()
    $PlayButton.Visibility = [System.Windows.Visibility]::Visible
    $LoopButton.Visibility = [System.Windows.Visibility]::Visible
    $PauseButton.Visibility = [System.Windows.Visibility]::Collapsed

    $message = "Unknown media error."

    if ($null -ne $eventArgs.ErrorException) {
        $message = $eventArgs.ErrorException.Message
    }

    Set-Status ("Media playback failed: {0}" -f $message)

    [System.Windows.MessageBox]::Show(
        $message,
        "Media playback failed"
    ) | Out-Null
})

$script:Player.Add_MediaEnded({
    if ($script:PlaybackMode -eq "Sequence" -and $script:PlaybackActive) {
        $script:Player.Position = [TimeSpan]::FromSeconds($script:PendingStart)
        $script:Player.Play()
        return
    }

    Pause-Playback
    $script:Player.Position = [TimeSpan]::FromSeconds($script:TotalDuration)
    Update-ProgressDisplay
    Set-Status "Full audio playback completed."
})

# ============================================================
# Progress slider events
# ============================================================

$ProgressSlider.Add_PreviewMouseLeftButtonDown({
    param($sender, $eventArgs)

    if (-not $ProgressSlider.IsEnabled) {
        return
    }

    Pause-Playback
    $script:UserSeeking = $true

    $source = $eventArgs.OriginalSource

    $thumb = Find-VisualAncestor `
        -Element $source `
        -TargetType ([System.Windows.Controls.Primitives.Thumb])

    if ($null -ne $thumb) { return }

    $track = Find-VisualAncestor `
        -Element $source `
        -TargetType ([System.Windows.Controls.Primitives.Track])

    if ($null -eq $track) {
        return
    }

    $eventArgs.Handled = $true

    try {
        $value = Get-SliderValueFromTrackPoint `
            -Track $track `
            -EventArgs $eventArgs

        Set-SelectedStart -Start $value | Out-Null
    }
    catch {
        Set-Status $_.Exception.Message
    }
})

$ProgressSlider.Add_ValueChanged({
    if (-not $script:UserSeeking -or
        $script:UpdatingSlider -or
        -not $ProgressSlider.IsEnabled) {
        return
    }

    try {
        $start = [double]$ProgressSlider.Value
        $range = Set-StartPosition -Start $start -Seek $true

        if ([Math]::Abs($range.Start - $start) -gt 0.000001) {
            $script:UpdatingSlider = $true

            try {
                $ProgressSlider.Value = $range.Start
            }
            finally {
                $script:UpdatingSlider = $false
            }
        }
    }
    catch {
        Set-Status $_.Exception.Message
    }
})

$ProgressSlider.Add_PreviewMouseLeftButtonUp({
    if (-not $script:UserSeeking) {
        return
    }

    $window.Dispatcher.BeginInvoke(
        [System.Action]{
            if (-not $script:UserSeeking) {
                return
            }

            try {
                $start = [double]$ProgressSlider.Value
                $script:UserSeeking = $false

                $range = Set-StartPosition -Start $start -Seek $true

                $script:UpdatingSlider = $true

                try {
                    $ProgressSlider.Value = $range.Start
                }
                finally {
                    $script:UpdatingSlider = $false
                }

            Set-Status "Sequence range updated."
            }
            catch {
                $script:UserSeeking = $false
                Set-Status $_.Exception.Message
            }
        },
        [System.Windows.Threading.DispatcherPriority]::Background
    ) | Out-Null
})

# ============================================================
# Start time input
# ============================================================

function Apply-EndInput {
    try {
        Pause-Playback
        $range = Update-EndFromInput
        $script:UpdatingSlider = $true
        try { $ProgressSlider.Value = $range.Start }
        finally { $script:UpdatingSlider = $false }
        Set-Status "End position updated."
    }
    catch {
        [System.Windows.MessageBox]::Show((Format-ErrorMessage $_.Exception.Message), "Invalid End Time", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        $script:UpdatingTimeFields = $true
        try { $EndBox.Text = Format-Time $script:PendingEnd }
        finally { $script:UpdatingTimeFields = $false }
    }
    finally {
        $script:StartInputDirty = $false
        $script:EndInputDirty = $false
    }
}

function Apply-StartInput {
    try {
        Pause-Playback
        $range = Update-RangeFromInput
        $script:UpdatingSlider = $true
        try { $ProgressSlider.Value = $range.Start }
        finally { $script:UpdatingSlider = $false }
        Set-Status "Start position updated."
    }
    catch {
        [System.Windows.MessageBox]::Show((Format-ErrorMessage $_.Exception.Message), "Invalid Start Time", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        $script:UpdatingTimeFields = $true
        try { $StartBox.Text = Format-Time $script:PendingStart }
        finally { $script:UpdatingTimeFields = $false }
    }
    finally {
        $script:StartInputDirty = $false
        $script:EndInputDirty = $false
    }
}

$StartBox.Add_TextChanged({ if (-not $script:UpdatingTimeFields) { $script:StartInputDirty = $true } })
$EndBox.Add_TextChanged({ if (-not $script:UpdatingTimeFields) { $script:EndInputDirty = $true } })

$EndBox.Add_PreviewKeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter) {
        $eventArgs.Handled = $true
        Apply-EndInput
    }
})
$EndBox.Add_LostFocus({ Apply-EndInput })

$StartBox.Add_PreviewKeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter) {
        $eventArgs.Handled = $true
        Apply-StartInput
    }
})
$StartBox.Add_LostFocus({ Apply-StartInput })

# ============================================================
# Enhancement UI events
# ============================================================

$GainSlider.Add_ValueChanged({
    $GainValueText.Text = "{0:+0.0;-0.0;0.0} dB" -f $GainSlider.Value
})

# ============================================================
# Browse buttons
# ============================================================

$BrowseWavButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "WAV files (*.wav)|*.wav"

    if ($dialog.ShowDialog()) {
        try {
            $wavPath = $dialog.FileName

            if ([System.IO.Path]::GetExtension($wavPath) -ine ".wav") {
                throw "Only WAV files are supported."
            }

            $info = Read-WavInfo -Path $wavPath
            $totalDuration = $info.TotalFrames / $SampleRate

            Pause-Playback

            $script:Player.Stop()
            $script:Player.Close()

            $script:MediaReady = $false
            $script:OpeningMedia = $false
            $script:MediaPath = ""

            Remove-PreviewFile

            $script:WavInfo = $info
            $script:TotalDuration = $totalDuration

            $WavPathBox.Text = $wavPath

            $ProgressSlider.Minimum = 0
            $ProgressSlider.Maximum = $totalDuration
            $ProgressSlider.Value = 0
            $ProgressSlider.IsEnabled = $true

            $CurrentTimeText.Text = "00:00:00"
            $TotalTimeText.Text = Format-Time $totalDuration

            Set-StartPosition -Start 0 -Seek $false | Out-Null

            Set-Status "WAV loaded. Click Play to create an enhanced preview."
        }
        catch {
            [System.Windows.MessageBox]::Show(
                (Format-ErrorMessage $_.Exception.Message),
                "WAV Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
    }
})

# Modern native Windows folder picker
$BrowseOutputButton.Add_Click({
    try {
        $initialPath = $OutputBox.Text.Trim()

        $selectedPath = [NativeFolderPicker]::PickFolder(
            [System.Windows.Interop.WindowInteropHelper]::new($window).Handle,
            $initialPath
        )

        if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
            $OutputBox.Text = $selectedPath
        }
    }
    catch {
        [System.Windows.MessageBox]::Show(
            (Format-ErrorMessage $_.Exception.Message),
            "Folder Selection Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
})

# ============================================================
# Sequence selection
# ============================================================

$SequenceBox.Add_SelectionChanged({
    if ($null -eq $SequenceBox.SelectedItem) {
        return
    }

    Pause-Playback

    try {
        $range = Set-StartPosition -Start 0 -Seek $true

        $script:UpdatingSlider = $true

        try {
            if ($ProgressSlider.IsEnabled) {
                $ProgressSlider.Value = $range.Start
            }
        }
        finally {
            $script:UpdatingSlider = $false
        }

        Set-Status "Sequence selected."
    }
    catch {
        $EndBox.Text = "--:--:--"
        Set-Status $_.Exception.Message
    }
})

# ============================================================
# Playback buttons
# ============================================================

function Request-Playback {
    param([ValidateSet("Full", "Sequence")][string]$Mode)

    try {
        if ($script:PreviewGenerating) {
            Set-Status "Enhanced preview is still generating..."
            return
        }

        if ($script:PlaybackActive) {
            Pause-Playback
            Set-Status "Paused."
            return
        }

        $script:PlaybackMode = $Mode

        $range = @{
            Start = $script:PendingStart
            End = $script:PendingEnd
        }

        $wavPath = $WavPathBox.Text.Trim()

        if (-not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
            throw "Please select a valid WAV file."
        }

        if ([System.IO.Path]::GetExtension($wavPath) -ine ".wav") {
            throw "Only WAV files are supported."
        }

        if ($null -eq $script:WavInfo -or
            $script:MediaPath -ne $wavPath) {

            $script:WavInfo = Read-WavInfo -Path $wavPath
            $script:TotalDuration = $script:WavInfo.TotalFrames / $SampleRate

            $range = Set-StartPosition `
                -Start $script:PendingStart `
                -Seek $false
        }

        if ($range.End -gt $script:TotalDuration + 0.000001) {
            $range = Set-StartPosition -Start $range.Start -Seek $false
        }

        # Rebuild preview if enhancement parameters changed.
        $gainDb = Get-GainDb
        $ceilingDb = Get-CeilingDb

        $parameterKey = "{0:F3}|{1:F3}" -f $gainDb, $ceilingDb

        $previewNeedsRebuild = (
            [string]::IsNullOrWhiteSpace($script:PreviewPath) -or
            -not (Test-Path -LiteralPath $script:PreviewPath) -or
            $script:PreviewParameterKey -ne $parameterKey -or
            $script:MediaPath -ne $wavPath
        )

        if ($previewNeedsRebuild) {
            if ($Mode -eq "Full" -and $script:MediaReady) {
                $script:PendingPlaybackPosition = $script:Player.Position.TotalSeconds
            }
            Pause-Playback

            $script:Player.Stop()
            $script:Player.Close()

            $script:MediaReady = $false
            $script:OpeningMedia = $true
            $script:MediaPath = $wavPath

            Remove-PreviewFile

            Set-Status "Generating enhanced preview..."
            $script:PendingPreviewStart = $range.Start
            $script:PendingPreviewEnd = $range.End
            $script:PreviewParameterKey = $parameterKey
            $script:PreviewSync = [hashtable]::Synchronized(@{ Path = $null; Error = $null })
            $sync = $script:PreviewSync
            $info = $script:WavInfo
            $sampleRate = $SampleRate
            $script:PreviewPowerShell = [System.Management.Automation.PowerShell]::Create()
            $null = $script:PreviewPowerShell.AddScript({
                param($sourcePath, $formatBytes, $dataOffset, $dataSize, $gain, $ceiling, $rate, $sync)
                $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("PBARPreview_{0}.wav" -f [guid]::NewGuid().ToString("N"))
                $source = $null
                $destination = $null
                $writer = $null
                try {
                    $source = [System.IO.File]::OpenRead($sourcePath)
                    $destination = [System.IO.File]::Create($tempPath)
                    $writer = New-Object System.IO.BinaryWriter($destination)
                    $fmtSize = $formatBytes.Length
                    $fmtPadding = $fmtSize % 2
                    $riffSize = 4 + 8 + $fmtSize + $fmtPadding + 8 + $dataSize
                    $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
                    $writer.Write([uint32]$riffSize)
                    $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
                    $writer.Write([uint32]$fmtSize)
                    $writer.Write($formatBytes)
                    if ($fmtPadding) { $writer.Write([byte]0) }
                    $writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
                    $writer.Write([uint32]$dataSize)
                    $source.Position = $dataOffset
                    [PcmEnhancer]::Process($source, $destination, $dataSize, $gain, $ceiling, $rate)
                    $sync.Path = $tempPath
                }
                catch {
                    $sync.Error = $_.Exception.Message
                    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
                }
                finally {
                    if ($null -ne $writer) { $writer.Dispose() }
                    elseif ($null -ne $destination) { $destination.Dispose() }
                    if ($null -ne $source) { $source.Dispose() }
                }
            }).AddArgument($wavPath).AddArgument($info.FormatBytes).AddArgument($info.DataOffset).AddArgument($info.DataSize).AddArgument($gainDb).AddArgument($ceilingDb).AddArgument($sampleRate).AddArgument($sync)
            $script:PreviewGenerating = $true
            $script:PreviewHandle = $script:PreviewPowerShell.BeginInvoke()
            $script:Timer.Start()
        }
        elseif ($script:MediaPath -eq $wavPath -and $script:MediaReady) {
            Start-Playback
        }
        elseif ($script:OpeningMedia) {
            Set-Status "Loading enhanced preview..."
        }
        else {
            $script:OpeningMedia = $true

            $script:Player.Open(
                [System.Uri]::new(
                    [System.IO.Path]::GetFullPath($script:PreviewPath)
                )
            )

            Set-Status "Loading enhanced preview..."
        }
    }
    catch {
        $script:OpeningMedia = $false

        [System.Windows.MessageBox]::Show(
            (Format-ErrorMessage $_.Exception.Message),
            "Playback Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null

        Set-Status ("Playback error: {0}" -f $_.Exception.Message)
    }
}

$PlayButton.Add_Click({ Request-Playback -Mode "Full" })
$LoopButton.Add_Click({ Request-Playback -Mode "Sequence" })
$PauseButton.Add_Click({
    Pause-Playback
    Set-Status "Paused."
})

# ============================================================
# Export button
# ============================================================

$ExportButton.Add_Click({
    $ExportButton.IsEnabled = $false

    try {
        $sequence = Get-SelectedSequence

        Pause-Playback

        $range = Update-RangeFromInput

        $script:UpdatingSlider = $true

        try {
            if ($ProgressSlider.IsEnabled) {
                $ProgressSlider.Value = $range.Start
            }
        }
        finally {
            $script:UpdatingSlider = $false
        }

        $wavPath = $WavPathBox.Text.Trim()
        $outputDir = $OutputBox.Text.Trim()

        if (-not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
            throw "Please select a valid WAV file."
        }

        if ([System.IO.Path]::GetExtension($wavPath) -ine ".wav") {
            throw "Only WAV files are supported."
        }

        if ([string]::IsNullOrWhiteSpace($outputDir)) {
            throw "Please specify an output directory."
        }

        if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Read current UI parameters at export time.
        $gainDb = Get-GainDb
        $ceilingDb = Get-CeilingDb

        Set-Status "Checking WAV format..."

        $info = Read-WavInfo -Path $wavPath
        $totalDuration = $info.TotalFrames / $SampleRate

        $startFrame = [long][Math]::Round(
            $range.Start * $SampleRate,
            [MidpointRounding]::AwayFromZero
        )

        $endFrame = [long][Math]::Round(
            $range.End * $SampleRate,
            [MidpointRounding]::AwayFromZero
        )

        if ($endFrame -gt $info.TotalFrames) {
            throw "Sequence exceeds source WAV duration."
        }

        $parts = @($sequence.parts)

        if ($parts.Count -eq 0) {
            throw "Sequence contains no parts."
        }

        $jobs = @()
        $clipLoopOffsets = @{}

        foreach ($part in $parts) {
            $clip = [string]$part.clip

            if ([string]::IsNullOrWhiteSpace($clip)) {
                throw "Part with missing clip ID."
            }

            if ($clip -notmatch '^\d+$') {
                throw "Invalid clip ID: $clip"
            }

            $relativeStart = [double]$part.start
            $relativeEnd = [double]$part.end

            if ([double]::IsNaN($relativeStart) -or
                [double]::IsInfinity($relativeStart) -or
                [double]::IsNaN($relativeEnd) -or
                [double]::IsInfinity($relativeEnd) -or
                $relativeStart -lt 0 -or
                $relativeEnd -le $relativeStart -or
                $relativeEnd -gt [double]$sequence.duration + 0.000001) {
                throw "Invalid time range for clip $clip."
            }

            $clipStart = [long][Math]::Round(
                ($range.Start + $relativeStart) * $SampleRate,
                [MidpointRounding]::AwayFromZero
            )

            $clipEnd = [long][Math]::Round(
                ($range.Start + $relativeEnd) * $SampleRate,
                [MidpointRounding]::AwayFromZero
            )

            if ($clipStart -lt $startFrame -or
                $clipEnd -gt $endFrame -or
                $clipEnd -le $clipStart -or
                $clipEnd -gt $info.TotalFrames) {
                throw "Clip $clip exceeds WAV boundaries."
            }

            $loops = if ($null -eq $part.loops) { 1 } else { [int]$part.loops }
            if ($loops -lt 1) {
                throw "Invalid loop count for clip $clip."
            }

            $partDuration = [double]$part.duration
            if ($partDuration -le 0) {
                throw "Invalid duration for clip $clip."
            }

            $loopOffset = if ($clipLoopOffsets.ContainsKey($clip)) { $clipLoopOffsets[$clip] } else { 0 }
            for ($loop = 1; $loop -le $loops; $loop++) {
                $loopStart = [double]$part.start + (($loop - 1) * $partDuration)
                $loopEnd = $loopStart + $partDuration
                $loopStartFrame = [long][Math]::Round(
                    ($range.Start + $loopStart) * $SampleRate,
                    [MidpointRounding]::AwayFromZero
                )
                $loopEndFrame = [long][Math]::Round(
                    ($range.Start + $loopEnd) * $SampleRate,
                    [MidpointRounding]::AwayFromZero
                )

                if ($loopStartFrame -lt $startFrame -or
                    $loopEndFrame -gt $endFrame -or
                    $loopEndFrame -le $loopStartFrame -or
                    $loopEndFrame -gt $info.TotalFrames) {
                    throw "Loop $loop for clip $clip exceeds WAV boundaries."
                }

                $outputLoop = $loopOffset + $loop
                $destination = Join-Path $outputDir ("{0}-{1}.wav" -f $clip, $outputLoop)

                $jobs += [PSCustomObject]@{
                    Clip = $clip
                    Loop = $outputLoop
                    StartFrame = $loopStartFrame
                    EndFrame = $loopEndFrame
                    Duration = ($loopEndFrame - $loopStartFrame) / $SampleRate
                    Destination = $destination
                }
            }
            $clipLoopOffsets[$clip] = $loopOffset + $loops
        }

        Set-Status ("Exporting {0} clips with Gain {1:F1} dB, Ceiling {2:F1} dBFS..." -f `
            $jobs.Count, $gainDb, $ceilingDb)

        $done = 0

        foreach ($job in $jobs) {
            Export-WavSegment `
                -SourcePath $wavPath `
                -DestinationPath $job.Destination `
                -FormatBytes $info.FormatBytes `
                -DataOffset $info.DataOffset `
                -StartFrame $job.StartFrame `
                -EndFrame $job.EndFrame `
                -GainDb $gainDb `
                -CeilingDb $ceilingDb

            $done++

            Set-Status ("Exported {0}/{1}: {2}-{3}.wav" -f `
                $done, $jobs.Count, $job.Clip, $job.Loop)

            [System.Windows.Forms.Application]::DoEvents()
        }

        Set-Status ("Completed. {0} clips exported. Gain: {1:F1} dB, Ceiling: {2:F1} dBFS." -f `
            $jobs.Count, $gainDb, $ceilingDb)

        [System.Windows.MessageBox]::Show(
            "Success.",
            "Export Complete",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
    catch {
        Set-Status ("Error: {0}" -f $_.Exception.Message)

        [System.Windows.MessageBox]::Show(
            (Format-ErrorMessage $_.Exception.Message),
            "Export Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $ExportButton.IsEnabled = $true
    }
})

# ============================================================
# Initialize
# ============================================================

$window.Add_Loaded({
    $window.Dispatcher.BeginInvoke(
        [Action]{
            try {
                $EndBox.Text = "--:--:--"
                $GainValueText.Text = "{0:+0.0;-0.0;0.0} dB" -f $GainSlider.Value
                if (Test-Path -LiteralPath $DefaultJson -PathType Leaf) {
                    Load-Sequences
                }
                else {
                    Set-Status "Select an ATOOL JSON and generate script.json."
                }
            }
            catch {
                [System.Windows.MessageBox]::Show(
                    (Format-ErrorMessage $_.Exception.Message),
                    "Initialization Error",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
            }
        },
        [System.Windows.Threading.DispatcherPriority]::ApplicationIdle
    ) | Out-Null
})

$window.Add_Closed({
    $script:Timer.Stop()

    if ($null -ne $script:PreviewPowerShell) {
        try { $script:PreviewPowerShell.Stop() } catch {}
        try { $script:PreviewPowerShell.Dispose() } catch {}
        $script:PreviewPowerShell = $null
    }

    if ($null -ne $script:PreviewSync -and
        -not [string]::IsNullOrWhiteSpace($script:PreviewSync.Path) -and
        (Test-Path -LiteralPath $script:PreviewSync.Path)) {
        try { Remove-Item -LiteralPath $script:PreviewSync.Path -Force } catch {}
    }

    try {
        $script:Player.Stop()
        $script:Player.Close()
    }
    catch {
    }

    Remove-PreviewFile
})

$null = $window.ShowDialog()
