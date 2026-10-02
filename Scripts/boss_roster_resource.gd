class_name BossRosterResource
extends Resource

## Holds every boss team that can be picked for a season's decider match.
## Loaded once by the BossRoster autoload — see data/boss_roster.gd.

@export var bosses: Array[BossTeam] = []
