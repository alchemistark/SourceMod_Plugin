#include <sourcemod>

new Handle:v_enable = INVALID_HANDLE;
new g_sindara[MAXPLAYERS+1];	//死んだらフラグ

public Plugin:myinfo = 
{
	name = "sindara",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "このゲームは死んだら負けだかんなー？",
	version = "1.0",
	url = ""
}

//既知のバグ

//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//cvar
	v_enable = CreateConVar("sm_sindara_enable", "1", "1 = 死んだら負けになる");
	
	//say関係コマンドを監視
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");

	//hook
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Pre);
	
	
	HookEvent("teamplay_point_startcapture", OnCap, EventHookMode_Pre);
	HookEvent("controlpoint_starttouch", OnCap, EventHookMode_Pre);

	AddCommandListener(Command_team, "jointeam");
	
}

//デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	ServerCommand("sm plugins reload sindara");
	ReplyToCommand(client,"sindaraプラグインをリロードしました。");
	return false;
}

public OnCap(Handle:event, const String:name[], bool:dontBroadcast){

	return Plugin_Handled;
	
}



//ﾁｬｯﾄﾄﾘｶﾞ用
public Action:Command_Say(client, const String:command[], argc){
	//sayコマンドの内容を確保 argcは必ず１（sayコマンドは発言全てを１語として送るようだ）

	new String:strSay[192];
	GetCmdArg(1,strSay, sizeof(strSay));
	
	if(strcmp(strSay,"sindara",true) == 0 && GetConVarInt(v_enable) == 1){

		//死んだらフラグを立てる
		if(g_sindara[client] == 0){
			g_sindara[client] = 1;
		}
	}else if(strcmp(strSay,"sinanai",true) == 0){
		g_sindara[client] = 0;
	}
}
	
//HookEvent ラウンド終了時
public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	
	new i;
	for(i = 0 ; i <= MAXPLAYERS ; i++){
		g_sindara[i] = 0;
	}
}


//HookEvent スポーン監視
public OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast){

	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_sindara[client] != 0){
		FakeClientCommandEx(client,"kill");
	}
}

//HookEvent 死亡確認
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_sindara[client] == 1){
		g_sindara[client] = 2;
		FakeClientCommandEx(client,"say sinda");
	}
	else if(g_sindara[client] == 2){
		//SetEventInt(event,"inflictor_entindex",0);
		//SetEventInt(event,"attacker",0);
		SetEventString(event,"weapon","eternal_reward");
		SetEventString(event,"weapon_logclassname","eternal_reward");
		SetEventInt(event,"weaponid",7);
		//SetEventInt(event,"damagebits",135270528);
		SetEventInt(event,"customkill",2);
		//SetEventInt(event,"death_flags",1); //制圧フラグ
		SetEventInt(event,"silent_kill",1);
		SetEventInt(event,"crit_type",2);
	
		new TF2GameRulesEntity = FindEntityByClassname(-1, "tf_gamerules");
		if(TF2GameRulesEntity == -1){
			PrintToServer("[sindara]ERROR no entity");
		}
		
		
	}
}
	
//クライアント切断時
public OnClientDisconnect(client){
	g_sindara[client] = 0;
}
	
//チーム変更監視(観戦))
public Action:Command_team(client, const String:command[], argc){
	
	//観戦に入ったらリセット
	
	//red,blue,spectate,auto
	new String:strjoin[10];
	GetCmdArg(1,strjoin, sizeof(strjoin));
	
	//観戦に入った
	if(strcmp(strjoin,"spectate",true) == 0){
		g_sindara[client] = 0;
	}
}
