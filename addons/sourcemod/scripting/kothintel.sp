#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

new Handle:v_enable = INVALID_HANDLE;
new Handle:v_spawn = INVALID_HANDLE;
new Handle:v_fastspawn = INVALID_HANDLE;
new Handle:v_slowspawn = INVALID_HANDLE;

new Handle:g_hTimer = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[TF2]King of The Intel",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "kothのCPをIntelに変更します",
	version = "1.0",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){

	//cmd
	// RegAdminCmd("sm_intelspawn", Cmd_IntelSpawn, 0, "Intelを出現させる");
	
	//cvar
	v_enable = CreateConVar("sm_ki_enable", "0", "機能を有効にする");
	v_spawn = CreateConVar("sm_ki_spawn", "6", "ゲーム開始時のスポーン時間");
	v_fastspawn = CreateConVar("sm_ki_fastspawn", "4", "キャプチャーされたチームのスポーン時間");
	v_slowspawn = CreateConVar("sm_ki_slowspawn", "8", "キャプチャーしたチームのスポーン時間");
	
	//event
	HookEvent("teamplay_round_active", OnRoundStart);
	HookEvent("teamplay_flag_event", OnIntelEvent);
	HookEvent("teamplay_point_unlocked", OnIntelUnlock);
	
	//ConVar変更監視
	HookConVarChange(v_enable, OnConVarChanged_enable);	
}

//ConVar変更監視 enable
public OnConVarChanged_enable(ConVar convar, const char[] oldValue, const char[] newValue){

	new ent = -1;

	//有効化
	if(StringToInt(newValue) == 1){
	
		while((ent = FindEntityByClassname(ent, "tf_logic_koth")) != -1){
			//リスタートする
			PrintToChatAll("[KothIntel] Plugin enable. Game restart.");
			ServerCommand("mp_restartgame 3");
			return;
		}
		
		PrintToServer("[KothIntel] Error:tf_logic_kothが見つかりません");
		SetConVarInt(convar,0,false,false);
	}
	else if(StringToInt(newValue) == 0){
		//Intelがあれば削除する
		while((ent = FindEntityByClassname(ent, "item_teamflag")) != -1){
			AcceptEntityInput(ent, "Kill");
		}
		Entity_Input("team_control_point_master","Enable");
		Entity_Input("team_control_point","Enable");
		Entity_Input("trigger_capture_area","Enable");
		Entity_Input("func_capturezone","Enable");
	}
}

//マップ終了時にプラグインも終了する
public OnMapEnd(){
	SetConVarInt(v_enable,0,false,false);
}
public OnPluginEnd(){
	SetConVarInt(v_enable,0,false,false);
}
	
//関数 インテルを作成する（既にあれば消去する
public Func_IntelSpawn(){

	new ent = -1;
	new entIntel = -1;
	new pos[3];
	
	//既に存在するIntelがあれば削除する
	Entity_Input("item_teamflag", "Kill");

	entIntel = CreateEntityByName("item_teamflag");
	
	DispatchSpawn(entIntel);
	
	ent = -1;
	while((ent = FindEntityByClassname(ent, "team_control_point")) != -1){
		if(pos[0] != 0){
			PrintToServer("[KothIntel] Error:CPが複数ある？(kothマップではないかもしれません)");
		}
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
	}
	pos[2] = pos[2] + 20;
	TeleportEntity(entIntel, pos, NULL_VECTOR, NULL_VECTOR);
}

//関数 EntityにInputを送信
public Entity_Input(String:classname[], String:Input[]){
	
	new ent = -1;  
 
	while ((ent = FindEntityByClassname(ent, classname)) != -1)  
	{
		//PrintToServer("entity %s find",classname);
		new ref = EntIndexToEntRef(ent);
		AcceptEntityInput(ref, Input);
	}
	
}

//関数 タイマー動作
public Func_Timer(int client, bool blMode){

	//Entity検索用
	new entCPmodel = -1;
	new entCP = -1;
	new entGameRule = -1;
	
	new String:strTemp[255];
	
	//タイマーのEntityを確保する
	new Handle:hBluEnt = GameRules_GetPropEnt("m_hBlueKothTimer");
	new Handle:hRedEnt = GameRules_GetPropEnt("m_hRedKothTimer");

	//CPのモデルEntityを確保
	while((entCPmodel = FindEntityByClassname(entCPmodel, "prop_dynamic")) != -1){
		GetEntPropString(entCPmodel, Prop_Data, "m_ModelName", strTemp, sizeof(strTemp));
		if(StrEqual(strTemp,"models/props_gameplay/cap_point_base.mdl")){
			//CPのEntityを確保
			break;
		}
	}
	//CPのEntityを確保
	while((entCP = FindEntityByClassname(entCP, "team_control_point")) != -1){
		break;
	}
	//ゲームルールのEntityを確保
	while((entGameRule = FindEntityByClassname(entGameRule, "tf_gamerules")) != -1){
		break;
	}
	
	//タイマーが動作中なら停止する
	if(IsValidHandle(g_hTimer)){
		KillTimer(g_hTimer);
		g_hTimer = INVALID_HANDLE;
	}
	
	if(blMode){
		//タイマー開始
		if(GetClientTeam(client) == TFTeam_Blue){
			//Blue作動
			AcceptEntityInput(hBluEnt, "Resume");
			//Red停止
			AcceptEntityInput(hRedEnt, "Pause");
			//内部タイマー作動
			g_hTimer = CreateTimer(GetEntPropFloat(hBluEnt, Prop_Send, "m_flTimeRemaining"), Timer_Start, TFTeam_Blue);
			//CPの表示を更新
			SetEntProp(entCPmodel, Prop_Data, "m_nSkin", 2);
			SetVariantInt(TFTeam_Blue);
			AcceptEntityInput(entCP, "SetOwner", client, client);
			//SpawnWaveTimeを設定
			SetVariantInt(GetConVarInt(v_slowspawn));
			AcceptEntityInput(entGameRule, "SetBlueTeamRespawnWaveTime", 0, 0);
			SetVariantInt(GetConVarInt(v_fastspawn));
			AcceptEntityInput(entGameRule, "SetRedTeamRespawnWaveTime", 0, 0);
		}
		else if(GetClientTeam(client) == TFTeam_Red){
			//Blue停止
			AcceptEntityInput(hBluEnt, "Pause");
			//Red作動
			AcceptEntityInput(hRedEnt, "Resume");
			//内部タイマー作動
			g_hTimer = CreateTimer(GetEntPropFloat(hRedEnt, Prop_Send, "m_flTimeRemaining"), Timer_Start, TFTeam_Red);
			//CPの表示を更新
			SetEntProp(entCPmodel, Prop_Data, "m_nSkin", 1);
			SetVariantInt(TFTeam_Red);
			AcceptEntityInput(entCP, "SetOwner", client, client);
			//SpawnWaveTimeを設定
			SetVariantInt(GetConVarInt(v_fastspawn));
			AcceptEntityInput(entGameRule, "SetBlueTeamRespawnWaveTime", 0, 0);
			SetVariantInt(GetConVarInt(v_slowspawn));
			AcceptEntityInput(entGameRule, "SetRedTeamRespawnWaveTime", 0, 0);
		}
	}
	else{
		//タイマー停止
		AcceptEntityInput(hRedEnt, "Pause");
		AcceptEntityInput(hBluEnt, "Pause");
		SetEntProp(entCPmodel, Prop_Data, "m_nSkin", 0);
		SetVariantInt(0);
		AcceptEntityInput(entCP, "SetOwner", 0, 0);
	}
}

//タイマー　作動
public Action:Timer_Start(Handle:timer, any:team){
	//Enable確認
	if(GetConVarInt(v_enable) == 0){
		return;
	}

	//タイマーが終了したらゲーム終了
	new ent = -1;
	while((ent = FindEntityByClassname(ent, "team_control_point_master")) != -1){
		//タイマー0のチームに勝利させる
		SetVariantInt(team);
		AcceptEntityInput(ent, "SetWinner");
	}
	new i;
	for(i = 1;i<MaxClients;i++){
		if(IsClientInGame(i) == true){
			if(GetClientTeam(i) == team || GetClientTeam(i) < 2){
				ClientCommand(i,"playgamesound Game.YourTeamWon");
			}
			else{
				ClientCommand(i,"playgamesound Game.YourTeamLost");
			}
		}
	}
}
	
//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){

	//Enable確認
	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//CP停止
	Entity_Input("team_control_point_master","Disable");
	Entity_Input("team_control_point","Disable");
	Entity_Input("trigger_capture_area","Disable");
	Entity_Input("func_capturezone","Disable");	

	//ゲームルールのEntityを確保
	new ent = -1;
	while((ent = FindEntityByClassname(ent, "tf_gamerules")) != -1){
		break;
	}
	//SpawnWaveTimeを設定
	SetVariantInt(GetConVarInt(v_spawn));
	AcceptEntityInput(ent, "SetBlueTeamRespawnWaveTime", 0, 0);
	SetVariantInt(GetConVarInt(v_spawn));
	AcceptEntityInput(ent, "SetRedTeamRespawnWaveTime", 0, 0);
}

//HookEvent CP開始時
public OnIntelUnlock(Handle:event, const String:name[], bool:dontBroadcast){

	//Enable確認
	if(GetConVarInt(v_enable) == 0){
		return;
	}

	//Intelを出現させる
	Func_IntelSpawn();
}

//HookEvent インテル状態
public OnIntelEvent(Handle:event, const String:name[], bool:dontBroadcast){

	//Enable確認
	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//インテルが拾われた
	if(GetEventInt(event, "eventtype") == TF_FLAGEVENT_PICKEDUP){
		Func_Timer(GetEventInt(event, "player"), true);
	}
	//インテルが落とされた
	if(GetEventInt(event, "eventtype") == TF_FLAGEVENT_DROPPED){
		Func_Timer(GetEventInt(event, "player"), false);
	}
	//インテルが戻された
	else if(GetEventInt(event, "eventtype") == TF_FLAGEVENT_RETURNED){
		//どこかに飛んで行くので再出現させる
		Func_IntelSpawn();
	}
}