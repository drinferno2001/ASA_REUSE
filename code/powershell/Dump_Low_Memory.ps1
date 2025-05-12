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

# Export Path

$lowMemoryDumpPath = "C:\Users\ryanwork\Desktop\ASA_HWD_RECON\Device_Dumps";

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

            Start-Sleep -Milliseconds 5000  # Give the device time to respond

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

            $createDate = (Get-Date).toString("MM_dd_yyyy");
            $addressContents | Out-File -FilePath "$($lowMemoryDumpPath)\Memory_Dump_$($createDate).txt" -Append -Confirm:$false;
        }catch{
            throw "RESPONSE PARSING/EXPORT ERROR: $($_)"
        }

        if($decimalAddress -gt 128){
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