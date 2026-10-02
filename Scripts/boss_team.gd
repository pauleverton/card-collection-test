class_name BossTeam
extends Resource

## One "boss" identity — a themed decider-match opponent with its own name,
## squad strength, and signature rule(s) that mess with your team's usual
## abilities (e.g. "your midfielder's support bonus doesn't apply here").
##
## A season's decider match (the last of LeagueState.MATCHES_PER_SEASON)
## picks one of these at random via BossRoster — see LeagueState — so
## replays face a different boss each time rather than the same fixed
## final match every run.
##
## Create these as .tres resources (same pattern as CardData), and add
## them to res://data/boss_roster.tres's "bosses" array in the Inspector.

@export var boss_name: String = ""

## Feeds SquadGenerator.generate_boss_squad() for this boss's opponent squad.
@export_enum("bronze", "silver", "gold") var base_rarity: String = "silver"

## This boss's signature rule(s). Each condition's description is what's
## shown to the player on the Season Prediction screen before they head to
## the transfer market; disables_support_bonus/attack_multiplier/
## defense_multiplier are what MatchLogic actually applies during the match.
@export var conditions: Array[MatchCondition] = []
