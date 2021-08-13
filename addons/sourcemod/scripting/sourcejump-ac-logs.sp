#include <sourcemod>

#include <bash2>

#include <ripext>
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

#define URL "https://sourcejump.net"
#define ENDPOINT "ac/log"

ConVar gCV_APIKey;
StringMap gSM_GameInfo;
HTTPClient gH_HTTPClient;

public Plugin myinfo =
{
	name = "SourceJump Anti-Cheat Logs",
	author = "Eric",
	description = "Sends anti-cheat detections to the SourceJump database.",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/-eric"
};

public void OnPluginStart()
{
	gCV_APIKey = CreateConVar("sourcejump_ac_logs_api_key", "", "SourceJump Anti-Cheat Logs API key.", FCVAR_PROTECTED);
	AutoExecConfig();

	gSM_GameInfo = new StringMap();
	gH_HTTPClient = new HTTPClient(URL);
}

public void OnConfigsExecuted()
{
	char apiKey[64];
	gCV_APIKey.GetString(apiKey, sizeof(apiKey));

	if (apiKey[0] == '\0')
	{
		LogError("SourceJump Anti-Cheat Logs API key is not set.");
		return;
	}

	gH_HTTPClient.SetHeader("api-key", apiKey);
}

public int SteamWorks_OnValidateClient(int ownerauthid, int authid)
{
	bool familyShared = false;

	if (ownerauthid != authid)
	{
		familyShared = true;
	}

	char steamID[32];
	Format(steamID, sizeof(steamID), "[U:1:%d]", authid);

	char ownerSteamID[32];
	Format(ownerSteamID, sizeof(ownerSteamID), "[U:1:%d]", ownerauthid);

	gSM_GameInfo.SetValue(steamID, familyShared);
	gSM_GameInfo.SetString(steamID, ownerSteamID);
}

public void Bash_OnDetection(int client, char[] buffer)
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	char steamID[32];
	GetClientAuthId(client, AuthId_Steam3, steamID, sizeof(steamID));

	char ip[16];
	GetClientIP(client, ip, sizeof(ip));

	bool familyShared;
	gSM_GameInfo.GetValue(steamID, familyShared);

	char ownerSteamID[32];
	gSM_GameInfo.GetString(steamID, ownerSteamID, sizeof(ownerSteamID));

	JSONObject json = new JSONObject();
	json.SetString("map", map);
	json.SetString("player", name);
	json.SetString("steamid", steamID);
	json.SetString("ip", ip);
	json.SetBool("game-family-shared", familyShared);
	json.SetString("game-owner", ownerSteamID);
	json.SetString("message", buffer);

	gH_HTTPClient.Post(ENDPOINT, json, OnDetectionSent);

	delete json;
}

public void OnDetectionSent(HTTPResponse response, any value, const char[] error)
{
	if (response.Status != HTTPStatus_Created)
	{
		LogError("Failed to send anti-cheat detection to the SourceJump database. Response status: %d.", response.Status);
	}
}
