###########################
# VARIABLE INITIALIZATION #
###########################

# Configure the serial port

$portName = "COM6"
$baudRate = 9600
$parity = [System.IO.Ports.Parity]::None
$dataBits = 8
$stopBits = [System.IO.Ports.StopBits]::One

# Initialize serial port object

$serialPort = New-Object System.IO.Ports.SerialPort $portName, $baudRate, $parity, $dataBits, $stopBits
$serialPort.ReadTimeout = 5000
$serialPort.WriteTimeout = 5000

# Check to see if this a test run (so that we don't try to pull back everything in memory)

$dryRun = $null;

try{
    Write-Host "";
    $testRunPrompt = Read-Host "Is this a test run? (Y for (YES) or anything else for (NO))"

    Write-Host "";
    if($testRunPrompt -eq "Y"){
        $dryRun = $true;
        Write-Host "TEST RUN SELECTED (ONLY PULL THE FIRST 512 BYTES)"
    }else{
        $dryRun = $false;
        Write-Host "PROD RUN SELECTED (PULLING ENTIRE FILE)"
    }
}catch{
    Write-Error "LOG: ERROR PROMPTING FOR SCRIPT EXECUTION MODE"
}

# Prompt for memory dump path

$lowMemoryDumpPath = $null;

try{
    Write-Host "";
    $lowMemoryDumpPath = Read-Host "Where do you want to save the dump (just folder name)"

    # Remove trailing backslash (if provided)
    $lowMemoryDumpPath = $lowMemoryDumpPath -replace '\\*$', "";
}catch{
    Write-Error "LOG: ERROR PROMPTING FOR DUMP FILE PATH"
}

Write-Host ""
Write-Host "USING DUMP DIRECTORY AT [$($lowMemoryDumpPath)]";

if(-Not(Test-Path -Path $lowMemoryDumpPath)){
    
    try{
        $null = New-Item -ItemType Directory $lowMemoryDumpPath;
    }catch{
        Write-Error "Error creating dump directory [$($lowMemoryDumpPath)]: $_"
    }

    Write-Host "LOG: DUMP DIRECTORY [$($lowMemoryDumpPath)] DIDN'T EXIST AND WAS CREATED.";
}else{
    Write-Host "LOG: DUMP DIRECTORY [$($lowMemoryDumpPath)] ALREADY EXISTS AND WILL NOT BE RE-CREATED.";
}

# Append filename at dump path

$dumpFile = "$($lowMemoryDumpPath)\Memory_Dump.txt";

##########
# SCRIPT #
##########

####################
# OPEN SERIAL PORT #
####################

try{
    $serialPort.Open()
    Write-Host ""
    Write-Host "LOG: SERIAL PORT [$($portName)] OPENED SUCCESSFULLY."
    Write-Host ""
}catch{
    Write-Error "FAILED TO OPEN SERIAL PORT: $_"
}

try{
    ########################
    # PULL MEMORY CONTENTS #
    ########################
  
    $startDate = (Get-Date).toString("MM/dd/yyyy hh:mm tt K");
    Write-Host "STARTING DEVICE DUMP ON [$($startDate)]";
    Write-Host ""

    # LOOP THROUGH ADDRESSES IN LOW MEMORY (< 1 MB)
    # AND PULL MEMORY CONTENTS

    # Define the memory address (represented as decimal number)

    $decimalAddress = 0

    # We will loop until we hit address 1048447 (0xFFF7F)
    # as the end of low memory is 0xFFFFF (and we capture 128 bytes in each call)
    while ($decimalAddress -le 1048447) {

        # Convert index to hex-based address value

        $hexAddress = "{0:X8}" -f $decimalAddress;

        $command = "D %$($hexAddress)";
        $addressContents = $null;

        try{

            Write-Host "LOG: Command: $($command)";

            # Send command

            $serialPort.Write("")
            $serialPort.Write("$($command)`r")

            Start-Sleep -Milliseconds 2000  # Give the device time to respond

            # Read response

            $addressContents = $serialPort.ReadExisting()

            if(-Not($addressContents)){
                throw "COMMAND [$($command)]: NO RESPONSE RECEIVED...";
            }
        }catch{
            throw "SERIAL COMMUNICATION ERROR: $_"
        }

        try{
            # Filter pulled instructions to remove empty lines and any prompts
        
            $addressContents = $addressContents -split '\r?\n';
        
            $addressContents = @($addressContents | ?{
                -Not($_ -match '^\rEBDEBUG.*$') -and
                -Not($_ -eq "") -and
                -Not($_ -match '^U.*$') -and
                -Not($_ -match '^D\ %.*')
            })

            # Export instructions to local path

            $addressContents | Out-File -FilePath $dumpFile -Append -Confirm:$false;
        }catch{
            throw "RESPONSE PARSING/EXPORT ERROR: $($_)"
        }

        # Break after 512 bytes (on 384 decimal address pull) in test mode
        if($decimalAddress -eq 384 -and $dryRun){
            break;
        }

        # Increment in values of 128
        $decimalAddress += 128;
    }
}catch{
    Write-Error "$_"
}finally{

    Write-Host ""
    $endDate = (Get-Date).toString("MM/dd/yyyy hh:mm tt K");
    Write-Host "ENDING DEVICE DUMP ON [$($endDate)]";

    #####################
    # CLOSE SERIAL PORT #
    #####################

    $serialPort.Close()

    Write-Host ""
    Write-Host "LOG: SERIAL PORT [$($portName)] CLOSED";
}

#######################################
# CONVERT HEXDUMP FILE TO BINARY FILE #
#######################################

try{
    Write-Host ""
    Write-Host "CONVERTING HEX DUMP FILE TO BINARY..."

    # Pull hexdump content

    $hexDump = Get-Content -Path $dumpFile -Raw;
    $hexDump = $hexDump -split "\n";

    # Clean up contents by removing address info (along with ASCII/character representation)

    try{
        $dumpFileLines = New-Object System.Collections.ArrayList;

        foreach($line in $hexDump){

            # Skip empty lines
            if([string]::IsNullOrWhiteSpace($line)){
                continue;
            }

            # Remove address
            $currentLine = $line.substring(15);

            # Remove ASCII/character representations
            $lineContents = $currentLine -split "\s+";
            $lineContents = @($lineContents[0..14]);

            # Remove middle semicolon
            $lineContents = $lineContents | ForEach-Object{$_ -replace ":", " "};

            $currentLine = $lineContents -join " ";

            $null = $dumpFileLines.Add($currentLine);
        }

        $hexDump = $dumpFileLines -join " ";
    }catch{
        throw "ERROR CLEANING UP HEXDUMP PRIOR TO CONVERSION: $($_)"
    }

    try{
        $binaryFile = "$($lowMemoryDumpPath)\Memory_Dump.bin";

        # Convert to binary by spliting the input string by 2-character sequences and prefixing '0X' to each 2-hex-digit string
        # (and then casting to a byte array)

        [byte[]]$bytes = ($hexDump -split '\s+' | ForEach-Object{$_ -replace '^', '0X'})
        [System.IO.File]::WriteAllBytes($binaryFile, $bytes)

        Write-Host ""
        Write-Host "FINISHED CONVERTING HEX DUMP FILE TO BINARY!"
    }catch{
        throw "ERROR WRITING BINARY CONTENTS: $($_)"
    }
}catch{
    Write-Error "$_"
}