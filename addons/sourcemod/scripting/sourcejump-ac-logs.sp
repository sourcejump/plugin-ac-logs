#include <bash2>
#include <json>
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

#define URL "https://sourcejump.net/ac/log"

ConVar gCV_APIKey;
StringMap gSM_GameInfo;

public Plugin myinfo =
{
	name = "SourceJump Anti-Cheat Logs",
	author = "Eric",
	description = "Sends anti-cheat detections to the SourceJump database.",
	version = "1.1.0",
	url = "https://steamcommunity.com/id/-eric"
};

public void OnPluginStart()
{
	gCV_APIKey = CreateConVar("sourcejump_ac_logs_api_key", "", "SourceJump Anti-Cheat Logs API key.", FCVAR_PROTECTED);
	AutoExecConfig();

	gSM_GameInfo = new StringMap();
}

public void SteamWorks_OnValidateClient(int ownerAuthID, int authID)
{
	bool familyShared = false;

	if (ownerAuthID != authID)
	{
		familyShared = true;
	}

	char steamID[32];
	Format(steamID, sizeof(steamID), "[U:1:%d]", authID);

	char ownerSteamID[32];
	Format(ownerSteamID, sizeof(ownerSteamID), "[U:1:%d]", ownerAuthID);

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

	JSON_Object json = new JSON_Object();
	json.SetString("map", map);
	json.SetString("player", name);
	json.SetString("steamid", steamID);
	json.SetString("ip", ip);
	json.SetBool("game-family-shared", familyShared);
	json.SetString("game-owner", ownerSteamID);
	json.SetString("message", buffer);

	SendDetection(json);

	delete json;
}

void SendDetection(JSON_Object json)
{
	char apiKey[64];
	gCV_APIKey.GetString(apiKey, sizeof(apiKey));

	if (apiKey[0] == '\0')
	{
		LogError("SourceJump Anti-Cheat Logs API key is not set.");
		return;
	}

	char body[2048];
	json.Encode(body, sizeof(body));

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, URL);
	SteamWorks_SetHTTPRequestHeaderValue(request, "api-key", apiKey);
	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", body, strlen(body));
	SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, 15000);
	SteamWorks_SetHTTPCallbacks(request, OnDetectionSent);
	SteamWorks_SendHTTPRequest(request);
}

public void OnDetectionSent(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, DataPack pack)
{
	if (failure || !requestSuccessful || statusCode != k_EHTTPStatusCode204NoContent)
	{
		LogError("Failed to send anti-cheat detection to the SourceJump database. Response status: %d.", statusCode);
	}

	delete request;
}
