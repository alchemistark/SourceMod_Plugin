#include <sourcemod>

//cvars
new Handle:v_enable = INVALID_HANDLE;		//有効無効


public Plugin:myinfo = 
{
	name = "[TF2]DisableTS",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "チームの変更を不許可にします。",
	version = "",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){
	
	//cvar
	v_enable = CreateConVar("sm_dts_enable", "0", "[DisableTS]プラグインの有効無効 1:有効 0:無効");
	
	//CommandListener(有利join禁止用)
	AddCommandListener(OnPlayerTeamChanged_Listen, "jointeam");
	
}

//CommandListener "jointeam"
public Action:OnPlayerTeamChanged_Listen(client, const String:command[], argc){

	//有利join防止の為、チーム変更不可（観戦に入ることもできない）
	if(GetConVarInt(v_enable) == 1 && IsClientInGame(client) == true && GetClientTeam(client) > 1){
		return Plugin_Handled;
	}
}