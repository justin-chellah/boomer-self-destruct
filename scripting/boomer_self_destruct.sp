#include <sourcemod>
#include <sdkhooks>

#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3

enum ZombieClassType
{
	Zombie_Common = 0,
	Zombie_Smoker,
	Zombie_Boomer,
	Zombie_Hunter,
	Zombie_Spitter,
	Zombie_Jockey,
	Zombie_Charger,
	Zombie_Witch,
	Zombie_Tank,
	Zombie_Survivor,
};

ConVar boomer_self_destruct_damage_interval = null;
float g_flTimeSinceAttackedBySurvivor[32+1] = { -1.0, ... };

bool IsButtonPressed( int iClient, int fButtons )
{
	return view_as< bool >( GetEntProp( iClient, Prop_Data, "m_afButtonPressed" ) & fButtons );
}

bool IsPlayerStaggering( int iClient )
{
	return GetEntPropFloat( iClient, Prop_Send, "m_staggerTimer", 1 ) != -1.0;
}

bool IsSpraying( int iClient )
{
	int iAbility = GetEntPropEnt( iClient, Prop_Send, "m_customAbility" );
	if ( iAbility != INVALID_ENT_REFERENCE )
	{
		return view_as< bool >( GetEntProp( iAbility, Prop_Send, "m_isSpraying", 1 ) );
	}
	
	return false;
}

ZombieClassType GetZombieClass( int iClient )
{
	return view_as< ZombieClassType >( GetEntProp( iClient, Prop_Send, "m_zombieClass" ) );
}

float GetTimeSinceAttackedBySurvivor( int iClient )
{
	float flDuration = g_flTimeSinceAttackedBySurvivor[iClient];
	if ( flDuration <= 0.0 )
	{
		return 99999.9;
	}
	
	return GetGameTime() - flDuration;
}

public void OnClientDisconnect( int iClient )
{
	g_flTimeSinceAttackedBySurvivor[iClient] = -1.0;
}

public void OnPlayerRunCmdPost( int iClient, int fButtons, int nImpulse, const float flVecVel[3], const float flVecAngles[3], int iWeapon, int nSubtype, int nCmdnum, int nTickcount, int nSeed, const int nMouse[2] )
{
	if ( !IsButtonPressed( iClient, IN_RELOAD ) )
	{
		return;
	}
	
	float flDamageInterval = boomer_self_destruct_damage_interval.FloatValue;
	
	if ( !IsPlayerAlive( iClient )
		|| GetClientTeam( iClient ) != TEAM_INFECTED
		|| GetZombieClass( iClient ) != Zombie_Boomer 
		|| IsPlayerStaggering( iClient )									// Allow survivors to kill Boomer while staggering
		|| IsSpraying( iClient )											// Can only do one of the two at a time
		|| GetTimeSinceAttackedBySurvivor( iClient ) < flDamageInterval )
	{
		return;
	}
	
	SDKHooks_TakeDamage( iClient, 0, -1, float( GetEntProp( iClient, Prop_Send, "m_iHealth" ) ), 
		DMG_BURN );		// Indicate that this was a manually triggered explosion
}

public void Event_player_hurt( Event hEvent, const char[] szName, bool bDontBroadcast )
{
	int iVictim = GetClientOfUserId( hEvent.GetInt( "userid" ) );
	int iAttacker = GetClientOfUserId( hEvent.GetInt( "attacker" ) );

	if ( GetClientTeam( iVictim ) != TEAM_INFECTED )
	{
		return;
	}
	
	if ( GetClientTeam( iAttacker ) != TEAM_SURVIVOR )
	{
		return;
	}
	
	// It takes a while for boomers to die by fire so let's make an exception
	int fDmgType = hEvent.GetInt( "type" );
	if ( fDmgType & DMG_BURN )
	{
		return;
	}
	
	g_flTimeSinceAttackedBySurvivor[iVictim] = GetGameTime();
}

public void Event_round_start( Event hEvent, const char[] szName, bool bDontBroadcast )
{
	for ( int iClient = 1; iClient <= MaxClients; iClient++ )
	{
		g_flTimeSinceAttackedBySurvivor[iClient] = -1.0;
	}
}

public void OnPluginStart()
{	
	HookEvent( "player_hurt", Event_player_hurt, EventHookMode_Post );
	HookEvent( "round_start", Event_round_start, EventHookMode_PostNoCopy );
	
	boomer_self_destruct_damage_interval = CreateConVar( "boomer_self_destruct_damage_interval", "1.0", "How many seconds must elapse before Boomer can blow themself up" );
}

public Plugin myinfo =
{
	name = "[L4D/2] Boomer Self-Destruct",
	author = "Justin \"Sir Jay\" Chellah",
	description = "Allows boomers to explode and splatter the survivors with vomit by pressing the RELOAD button",
	version = "1.0.0",
	url = "https://justin-chellah.com"
};