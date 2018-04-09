#include <sourcemod>
#include <sdktools>

new Handle:v_enable = INVALID_HANDLE;

new float:g_fBluTime;
new float:g_fRedTime;

new bool:g_bBluActive;
new bool:g_bRedActive;

new Handle:g_hBluEnt;
new Handle:g_hRedEnt;

public Plugin:myinfo = 
{
	name = "[TF2]KOTH timer",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "KOTHのタイマーを操作する",
	version = "1.0",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){

	//cmd
	RegAdminCmd("sm_stop", Cmd_stop, 0, "");
	RegAdminCmd("sm_start", Cmd_start, 0, "");
	RegAdminCmd("sm_set", Cmd_set, 0, "");
	RegAdminCmd("sm_get", Cmd_get, 0, "");
	
	//cvar
	v_enable = CreateConVar("sm_kothtimer_enable", "0", "機能を有効にする");
	
}

public Func_Timer(client){

	if(GetConVarInt(v_enable) == 0){
		return false;
	}

	//タイマーのEntityを確保する
	g_hBluEnt = GameRules_GetPropEnt("m_hBlueKothTimer");
	g_hRedEnt = GameRules_GetPropEnt("m_hRedKothTimer");
	
	if(g_hBluEnt == -1 || g_hRedEnt == -1){
		PrintToChat(client,"kothのタイマーが存在しない？もしくはマップがkothでない");
		return false;
	}
	
	//青タイマー確認	//止まっていると1、動いていると0
	if(GetEntProp(g_hBluEnt, Prop_Send, "m_bTimerPaused") == 0){
		//タイマー動作中(タイマー開始時の時刻－現在時刻）
		g_fBluTime = GetEntPropFloat(g_hBluEnt, Prop_Send, "m_flTimerEndTime") -  GetGameTime();
		g_bBluActive = true;
	}
	else{
		//タイマー停止中
		g_fBluTime = GetEntPropFloat(g_hBluEnt, Prop_Send, "m_flTimeRemaining");
		g_bBluActive = false;
	}
	//赤タイマー確認
	if(GetEntProp(g_hRedEnt, Prop_Send, "m_bTimerPaused") == 0){
		g_fRedTime = GetEntPropFloat(g_hRedEnt, Prop_Send, "m_flTimerEndTime") -  GetGameTime();
		g_bRedActive = true;
	}
	else{
		g_fRedTime = GetEntPropFloat(g_hRedEnt, Prop_Send, "m_flTimeRemaining");
		g_bRedActive = false;
	}
	
	return true;
	
}

public Action:Cmd_get(client, args){

	//タイマー情報の更新
	if(Func_Timer(client) == false){
		return Plugin_Continue;
	}
		
	new String:strTemp[255];
	
	if(g_bBluActive){
		strTemp = "BlueTimer:Active ";
	}
	else{
		strTemp = "BlueTimer:Stop ";
	}
	if(g_bRedActive){
		Format(strTemp, sizeof(strTemp), "%sRedTimer:Active", strTemp);
	}
	else{
		Format(strTemp, sizeof(strTemp), "%sRedTimer:Stop", strTemp);
	}
	
	//表示する
	PrintToChat(client,"Blue:%f Red:%f",g_fBluTime,g_fRedTime);
	PrintToChat(client,"%s",strTemp);
}

public Action:Cmd_stop(client, args){
	
	new ent;
	new String:strModelName[255];
	
	//タイマー情報の更新
	if(Func_Timer(client) == false){
		return Plugin_Continue;
	}
	
	//1を書き込むと停止するが、同時にタイマーがm_flTimeRemainingの値で初期化されるのに注意
	//実行前に値を取得して、停止後に上書きするべきか
	// SetEntPropFloat(g_hBluEnt, Prop_Send, "m_flTimeRemaining",g_fBluTime);
	// SetEntPropFloat(g_hRedEnt, Prop_Send, "m_flTimeRemaining",g_fRedTime);
	// SetEntProp(g_hBluEnt, Prop_Send, "m_bTimerPaused",1);
	// SetEntProp(g_hRedEnt, Prop_Send, "m_bTimerPaused",1);
	
	//こっちで止めた方が確実で安全
	AcceptEntityInput(g_hBluEnt, "Pause");
	AcceptEntityInput(g_hRedEnt, "Pause");
	
	PrintToChat(client,"タイマーを停止しました。");
	
	while((ent = FindEntityByClassname(ent, "team_control_point")) != -1){	//名前からエンティティを探す CBaseAnimating
		SetVariantInt(0);
		AcceptEntityInput(ent, "SetOwner", 0, 0);
		PrintToChat(client,"CP(Index:%d)を開放しました。", GetEntProp(ent, Prop_Data, "m_iPointIndex"));
	}
	
	ent = -1;
	
	while((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1){	//名前からエンティティを探す
		GetEntPropString(ent, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
		if(StrEqual(strModelName,"models/props_gameplay/cap_point_base.mdl")){
			//CPのスキンを初期化しておく
			SetEntProp(ent, Prop_Data, "m_nSkin", 0);
		}
	}	
}

public Action:Cmd_start(client, args){

	new String:strArg[2];
	new String:strModelName[255];
	new timerent;
	new cpent;
	new findent;
	
	GetCmdArg(1, strArg, sizeof(strArg));
	
		//タイマー情報の更新
	if(Func_Timer(client) == false){
		return Plugin_Continue;
	}
	
	while((findent = FindEntityByClassname(findent, "team_control_point")) != -1){	//名前からエンティティを探す CBaseAnimating
		timerent = findent;
	}
	
	findent = -1;
	while((findent = FindEntityByClassname(findent, "prop_dynamic")) != -1){	//名前からエンティティを探す
		GetEntPropString(findent, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
		if(StrEqual(strModelName,"models/props_gameplay/cap_point_base.mdl")){
			//CPのEntityを確保
			cpent = findent;
		}
	}	
	
	if(StringToInt(strArg) != 3){
		if(GetEntProp(g_hRedEnt, Prop_Send, "m_bTimerPaused") == 1){
			AcceptEntityInput(g_hRedEnt, "Resume");
			SetEntProp(cpent, Prop_Data, "m_nSkin", 1);
			SetVariantInt(2);
			AcceptEntityInput(timerent, "SetOwner", 0, 0);
			PrintToChat(client, "RedTimer start");
		}
	}
	if(StringToInt(strArg) != 2){
		if(GetEntProp(g_hBluEnt, Prop_Send, "m_bTimerPaused") == 1){
			AcceptEntityInput(g_hBluEnt, "Resume");
			SetEntProp(cpent, Prop_Data, "m_nSkin", 2);
			SetVariantInt(3);
			AcceptEntityInput(timerent, "SetOwner", 0, 0);
			PrintToChat(client, "BlueTimer start");
		}
	}
	
	//一旦CPをロックして、CPの取得状況をクリアする(必須)
	SetVariantInt(1);
	AcceptEntityInput(timerent, "SetLocked");
	
	CreateTimer(0.1, Cmd_EnableCP,timerent);
}

public Action:Cmd_EnableCP(Handle:timer, any:ent){
	SetVariantInt(0);
	AcceptEntityInput(ent, "SetLocked");
}

public Action:Cmd_set(client, args){

	new String:strArg[20];
	new iTime;
	
	GetCmdArg(1, strArg, sizeof(strArg));
	iTime = StringToInt(strArg);
	
	if(iTime == 0){
		PrintToChat(client,"up to 1");
		return Plugin_Continue;
	}
	
	//タイマー情報の更新
	if(Func_Timer(client) == false){
		return Plugin_Continue;
	}
	
	SetVariantInt(iTime);
	AcceptEntityInput(g_hBluEnt, "SetTime");
	SetVariantInt(iTime);
	AcceptEntityInput(g_hRedEnt, "SetTime");
	
	PrintToChat(client, "TimerSet:%d", iTime);
	
}