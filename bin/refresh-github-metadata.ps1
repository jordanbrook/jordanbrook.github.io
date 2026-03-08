param(
    [string]$RepositoriesConfig = "_data/repositories.yml",
    [string]$OutputPath = "_data/github-metadata.yml"
)

$ErrorActionPreference = "Stop"

function Invoke-GitHubRequest {
    param([string]$Uri)

    $headers = @{
        "User-Agent" = "Codex"
        "Accept"     = "application/vnd.github+json"
    }

    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }

    Invoke-RestMethod -Headers $headers -Uri $Uri
}

function Read-RepositoryConfig {
    param([string]$Path)

    $githubUsers = @()
    $githubRepos = @()
    $mode = ""

    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*github_users:\s*$') {
            $mode = "users"
            continue
        }

        if ($line -match '^\s*github_repos:\s*$') {
            $mode = "repos"
            continue
        }

        if ($line -match '^\s*-\s*(.+?)\s*$') {
          if ($mode -eq "users") {
              $githubUsers += $matches[1]
          } elseif ($mode -eq "repos") {
              $githubRepos += $matches[1]
          }
        }
    }

    [PSCustomObject]@{
        Users = $githubUsers
        Repos = $githubRepos
    }
}

function Get-UserSummary {
    param([string]$Username)

    $user = Invoke-GitHubRequest -Uri "https://api.github.com/users/$Username"
    $repos = Invoke-GitHubRequest -Uri "https://api.github.com/users/$Username/repos?per_page=100"
    $sortedRepos = @($repos | Sort-Object stargazers_count -Descending)
    $languages = @($repos | Where-Object { $_.language } | Group-Object language | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object { $_.Name })

    [PSCustomObject]@{
        username      = $user.login
        name          = $user.name
        html_url      = $user.html_url
        avatar_url    = $user.avatar_url
        bio           = $user.bio
        location      = $user.location
        public_repos  = $user.public_repos
        stars         = ($repos | Measure-Object -Property stargazers_count -Sum).Sum
        followers     = $user.followers
        following     = $user.following
        achievements  = @()
        top_languages = $languages
        top_repo      = if ($sortedRepos.Count -gt 0) { $sortedRepos[0].full_name } else { $null }
    }
}

function Get-RepoSummary {
    param([string]$Repository)

    $repo = Invoke-GitHubRequest -Uri "https://api.github.com/repos/$Repository"
    [PSCustomObject]@{
        name        = $repo.name
        full_name   = $repo.full_name
        html_url    = $repo.html_url
        description = $repo.description
        language    = $repo.language
        stars       = $repo.stargazers_count
        forks       = $repo.forks_count
        issues      = $repo.open_issues_count
    }
}

$config = Read-RepositoryConfig -Path $RepositoriesConfig
$yamlLines = @("users:")

foreach ($username in $config.Users) {
    $user = Get-UserSummary -Username $username
    $yamlLines += "  $($user.username):"
    $yamlLines += "    username: $($user.username)"
    if ($user.name) { $yamlLines += "    name: `"$($user.name)`"" }
    $yamlLines += "    html_url: $($user.html_url)"
    $yamlLines += "    avatar_url: $($user.avatar_url)"
    if ($user.bio) { $yamlLines += "    bio: `"$($user.bio.Replace('"', '\"'))`"" }
    if ($user.location) { $yamlLines += "    location: `"$($user.location.Replace('"', '\"'))`"" }
    $yamlLines += "    public_repos: $($user.public_repos)"
    $yamlLines += "    stars: $($user.stars)"
    $yamlLines += "    followers: $($user.followers)"
    $yamlLines += "    following: $($user.following)"
    $yamlLines += "    achievements: []"
    $yamlLines += "    top_languages:"
    foreach ($language in $user.top_languages) {
        $yamlLines += "      - `"$language`""
    }
}

$yamlLines += ""
$yamlLines += "repos:"

foreach ($repository in $config.Repos) {
    $repo = Get-RepoSummary -Repository $repository
    $yamlLines += "  $repository:"
    $yamlLines += "    name: `"$($repo.name)`""
    $yamlLines += "    full_name: $($repo.full_name)"
    $yamlLines += "    html_url: $($repo.html_url)"
    if ($repo.description) { $yamlLines += "    description: `"$($repo.description.Replace('"', '\"'))`"" }
    if ($repo.language) { $yamlLines += "    language: `"$($repo.language)`"" }
    $yamlLines += "    stars: $($repo.stars)"
    $yamlLines += "    forks: $($repo.forks)"
    $yamlLines += "    issues: $($repo.issues)"
}

Set-Content -Path $OutputPath -Value $yamlLines
Write-Host "Wrote $OutputPath"
