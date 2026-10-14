param([Parameter(Mandatory)][string] $RepositoryRoot, [Parameter(Mandatory)][string] $OutputPath)
$ErrorActionPreference = 'Stop'
$sourcePath = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'docs/jury-panel-final/JuryVotingService.cs'))
$source = [IO.File]::ReadAllText($sourcePath, [Text.Encoding]::UTF8)
$firstMarker = '        public async Task<JuryVotingPlayDetailViewModel> BuildPlayDetailPageModelAsync('
$endMarker = '        public async Task<JuryVotingComplexTableViewModel> BuildGameListTableModelAsync('
$start = $source.IndexOf($firstMarker, [StringComparison]::Ordinal)
$end = $source.IndexOf($endMarker, [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -le $start) { throw 'Actual voting service extraction markers changed. Update the test harness explicitly.' }
$methods = $source.Substring($start, $end - $start)
$line = ($source.Substring(0, $start).Split("`n")).Length
$prefix = @'
// Generated into obj from the actual company jury-panel service.
// Method bodies are unmodified; the bridge supplies the company context shape.
#nullable enable
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Data;
using System.Diagnostics;
using System.Text.Json;
using YKBAfife.Models.Entities;
using YkbAfife.Domain.Model.Data.JuryVoting;
using JuryVotes = YKBAfife.Models.Entities.JuryVote;
namespace AdditionalVotingRules.Tests;
internal sealed class JuryVotingService(VotingContextBridge context, ILogger<JuryVotingService> logger)
{
    private readonly VotingContextBridge _context = context;
    private readonly ILogger<JuryVotingService> _logger = logger;
'@
$generated = $prefix + "`n#line $line `"$($sourcePath.Replace('\', '/'))`"`n" + $methods + "`n#line default`n}`n"
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath))) | Out-Null
[IO.File]::WriteAllText($OutputPath, $generated, (New-Object Text.UTF8Encoding($false)))
