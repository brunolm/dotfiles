# NVMe link/idle power settings.
#
# Windows parks the NVMe controller in a non-operational power state after the primary
# idle timeout elapses with no I/O (200ms on AC out of the box), and NOPPME lets it do so
# without waiting for the controller to go quiescent. A drive that wakes back up too
# slowly surfaces as a storport timeout: bugcheck 0x124 with error source 0x10 (device
# driver), sometimes preceded by 0x154 when the stall lands on a store page-in.
#
# "original" is stock Windows/OEM; "power" relaxes it; "nvme-safe" keeps the drive awake.
# Every preset leaves the DC side at stock - parking the drive is a real battery saver and
# the wake stall only shows up on AC.
function B-PC-Set-StorageProfile {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet('nvme-safe', 'power', 'original', 'status')]
    [string]$Preset = 'status',
    [switch]$AllSchemes
  )

  $settings = PCStorage-Settings
  if ($Preset -eq 'status') {
    PCPower-Status $settings
    return
  }

  $applied = PCPower-ApplyPreset $Preset $settings (PCStorage-Presets)[$Preset] $AllSchemes
  if ($applied) { PCPower-Status $settings }
}

# Subgroup + setting GUIDs. The NVMe entries are marked hidden, so they never show up in
# powercfg /query or the Control Panel UI and have to be addressed by GUID.
function PCStorage-Settings() {
  $disk = '0012ee47-9041-4b5d-9b77-535fba8b1442'
  $pcie = '501a4d13-42af-4429-9fd1-a8218c268e20'

  return [ordered]@{
    Aspm                   = @{ Sub = $pcie; Guid = 'ee12f906-d277-404b-b6da-e5fa1a576df5'; Label = 'PCIe ASPM'; Unit = 'aspm' }
    DiskIdle               = @{ Sub = $disk; Guid = '6738e2c4-e8a5-4a42-b16a-e040e769756e'; Label = 'Turn off hard disk after'; Unit = 's' }
    NvmePrimaryIdle        = @{ Sub = $disk; Guid = 'd639518a-e56d-4345-8af2-b9f32fb26109'; Label = 'NVMe primary idle timeout'; Unit = 'ms' }
    NvmeSecondaryIdle      = @{ Sub = $disk; Guid = 'd3d55efd-c1ff-424e-9dc3-441be7833010'; Label = 'NVMe secondary idle timeout'; Unit = 'ms' }
    NvmeThresholdPrimary   = @{ Sub = $disk; Guid = 'fc95af4d-40e7-4b6d-835a-56d131dbc80e'; Label = 'NVMe primary threshold'; Unit = 'us' }
    NvmeThresholdSecondary = @{ Sub = $disk; Guid = 'dbc9e238-6de9-49e3-92cd-8c2b4946b472'; Label = 'NVMe secondary threshold'; Unit = 'us' }
    Noppme                 = @{ Sub = $disk; Guid = 'fc7372b6-ab2d-43ee-8797-15e9841f2cca'; Label = 'NVMe NOPPME'; Unit = 'bool' }
  }
}

# Each entry is @(AC, DC). A threshold of 0 means no non-operational state qualifies,
# because none has an ENLAT+EXLAT at or below zero.
function PCStorage-Presets() {
  return [ordered]@{
    'nvme-safe' = [ordered]@{
      Aspm                   = @(0, 2)
      DiskIdle               = @(0, 60)
      NvmePrimaryIdle        = @(60000, 100)
      NvmeSecondaryIdle      = @(60000, 1000)
      NvmeThresholdPrimary   = @(0, 50)
      NvmeThresholdSecondary = @(0, 100)
      Noppme                 = @(0, 0)
    }
    'power'     = [ordered]@{
      Aspm                   = @(1, 2)
      DiskIdle               = @(900, 60)
      NvmePrimaryIdle        = @(60000, 100)
      NvmeSecondaryIdle      = @(60000, 1000)
      NvmeThresholdPrimary   = @(15, 50)
      NvmeThresholdSecondary = @(100, 100)
      Noppme                 = @(0, 0)
    }
    'original'  = [ordered]@{
      Aspm                   = @(2, 2)
      DiskIdle               = @(30, 60)
      NvmePrimaryIdle        = @(200, 100)
      NvmeSecondaryIdle      = @(2000, 1000)
      NvmeThresholdPrimary   = @(15, 50)
      NvmeThresholdSecondary = @(100, 100)
      Noppme                 = @(1, 0)
    }
  }
}
