<#
.SYNOPSIS
Build the container
.PARAMETER RepoTags
Show existing tags for this container in the Docker registry
.PARAMETER Build
Build the container using the tag specified by -Repository, -Name, and -Version
.PARAMETER Push
Push an already built container using the tag specified by -Repository, -Name, and -Version
.PARAMETER Build
Build and then push the container using the tag specified by -Repository, -Name, and -Version
#>
[CmdletBinding(DefaultParameterSetName="RepoTags")] Param(
    [Parameter(ParameterSetName="RepoTags")] [switch] $RepoTags,
    [Parameter(ParameterSetName="Build")] [switch] $Build,
    [Parameter(ParameterSetName="Push")] [switch] $Push,
    [Parameter(ParameterSetName="BuildPush")] [switch] $BuildPush,
    $Repository = "mrled",
    $Name = "bsv",
    $Version = (Get-Content -Path $PSScriptRoot\VERSION | Select-Object -First 1),
    [switch] $Force
)

function Get-PushedTags {
    [CmdletBinding()] Param(
        [Parameter(Mandatory)] $Repository,
        [Parameter(Mandatory)] $Name
    )
    $tagsUri = "https://registry.hub.docker.com/v1/repositories/$Repository/$Name/tags"
    $tagsObj = Invoke-RestMethod -Uri $tagsUri
    $tagsObj.name
}

$fullTag = "${Repository}/${Name}:${Version}"

switch -Wildcard ($PSCmdlet.ParameterSetName) {
    "Build*" {
        docker build --tag "$fullTag" "$PSScriptRoot"
    }
    "*Push" {
        if (-not $Force -and $Version -in (Get-PushedTags -Repository $Repository -Name $Name)) {
            throw "Version '$Version' already pushed as '$fullTag' and -Force was not passed"
        }
        docker push "$fullTag"
    }
    "RepoTags" {
        Get-PushedTags -Repository $Repository -Name $Name
    }
}
