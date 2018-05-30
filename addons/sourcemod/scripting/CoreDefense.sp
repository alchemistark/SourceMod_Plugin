#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>

#define BLOCK_SIZE 48.0

new Handle:v_enable = INVALID_HANDLE;
new Handle:v_block = INVALID_HANDLE;
new Handle:v_distance = INVALID_HANDLE;
new Handle:v_health = INVALID_HANDLE;
new Handle:v_core_health = INVALID_HANDLE;


new g_PropEnt[MAXPLAYERS+1];	//各プレイヤーの仮ブロックEntity
new g_Button[MAXPLAYERS+1];	//各プレイヤーの入力スキャン用
new g_Set[MAXPLAYERS+1];	//各プレイヤーのブロック設置モードonoff
new g_block[MAXPLAYERS+1];	//各プレイヤーのブロック所有数
new g_Hit = -1;				//トレースフィルター用フラグ

new bool:g_Locker = false;

public Plugin:myinfo =
{
	//プラグイン情報を記述
	name = "[TF2]CoreDefense",
	author = "AMG",
	description = "",
	version = "",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){

	//cmd
	RegAdminCmd("sm_reload", Cmd_reload, Admin_Kick, "デバッグコマンド - プラグインをリロードする");
	RegAdminCmd("sm_core", Cmd_CoreSet, Admin_Kick, "マップのCoreを設定する");
	
	//cvar
	v_enable = CreateConVar("sm_cd_enable", "0", "モードのオンオフ");
	v_block = CreateConVar("sm_cd_block", "2", "所持できるブロック数");
	v_distance = CreateConVar("sm_cd_distance", "300", "ブロックを設置できる距離");
	v_health = CreateConVar("sm_cd_health", "200", "ブロックのヘルス");
	v_core_health = CreateConVar("sm_cd_corehealth", "15000", "コアブロックのヘルス");

	//hook
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("item_pickup", OnItemPikup);
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("teamplay_round_active", OnRoundStart);
	HookEvent("teamplay_point_unlocked", OnUnlock);
	HookEvent("post_inventory_application", OnUseLocker);
	
	HookEntityOutput("prop_dynamic","OnTakeDamage",OnTakeDamage);
	HookEntityOutput("prop_dynamic","OnBreak",OnBreak);
	
	HookConVarChange(v_enable, OnConVarChanged_enable);
	
	//関数 モデルDLリスト
	Func_ModelDL();
}

//マップ終了時にプラグインも終了する
public OnMapStart(){
	SetConVarInt(v_enable,0,false,false);
}
public OnMapEnd(){
	SetConVarInt(v_enable,0,false,false);
}
public OnPluginEnd(){
	SetConVarInt(v_enable,0,false,false);
}
	
//ConVar変更時（プラグイン有効無効切り替え時）
public OnConVarChanged_enable(ConVar convar, const char[] oldValue, const char[] newValue){

	//プラグインが有効化された
	if(StringToInt(newValue) == 1){
		//初期化処理
		Func_Start();
	
		//リスタートする
		PrintToChatAll("[CoreDefense] Plugin enable. Game restart.");
		ServerCommand("mp_restartgame 3");
	}
	else if(StringToInt(newValue) == 0){	
		//終了処理
		Func_End();
	}
	//不正な値の場合元に戻す
	else{
		PrintToServer("[WDM]ERROR:ConVar値が不正です。");
		SetConVarInt(convar,StringToInt(oldValue));
	}
}

//cmd デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	
	new String:strName[255];
	
	GetPluginFilename(INVALID_HANDLE, strName, sizeof(strName));
	ServerCommand("sm plugins reload %s", strName);
	GetPluginInfo(INVALID_HANDLE, PlInfo_Name, strName, sizeof(strName));
	ReplyToCommand(client,"reload plugin '%s'", strName);
}

//cmd Core設定
public Action:Cmd_CoreSet(client, args){

	if(GetConVarInt(v_enable) == 0){
		return;
	}

	new ent = -1;
	new iCount;
	new entCore[2] = {-1,-1};
	new entTeam[2];
	new Float:VecCore[2][3];
	new Float:VecTemp[3];
	new String:strName[255];
	new String:strPath[PLATFORM_MAX_PATH];
	
	new Handle:kvCore = INVALID_HANDLE;
	
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)  
	{
		GetEntPropString(ent, Prop_Data, "m_iName", strName, sizeof(strName));
		//cd_から始まるprop_dynamicをカウント
		if(!strncmp(strName, "cd_", 3)){
			//最初の2つのEnt番号は確保しておく
			if(iCount < 2){
				entCore[iCount] = ent;
				//ブロックの設置チームを確保
				if(!strncmp(strName[3], "2", 1)){
					entTeam[iCount] = TFTeam_Red;
				}
				else{
					entTeam[iCount] = TFTeam_Blue;
				}
			}
			iCount++;
		}
	}

	//設置されているブロックが無いか2つより多い
	if(iCount <= 0 || iCount > 2){
		PrintToServer("[CoreDefense] ERROR:実行に必要なブロックは1つまたは2つです。");
		return;
	}
	
	//各チームのブロックそれぞれ１つずつじゃない
	if(entTeam[0] == entTeam[1]){
		PrintToServer("[CoreDefense] ERROR:ブロックは各チーム１つずつにしてください。");
		return;
	}
	
	//既設ブロック座標を確保(ここに来た時点で１つはブロックを認識しているはず)
	GetEntPropVector(entCore[0], Prop_Data, "m_vecOrigin", VecCore[0]);
	
	//ブロック設置数１
	if(iCount == 1){
		//再利用のため初期化
		iCount = 0;
		//kothのみ実行
		if(FindEntityByClassname(ent, "tf_logic_koth") == -1){
			PrintToServer("[CoreDefense] ERROR:ブロック１つでの実行はkothマップのみです。");
			return;
		}
		//CP確保
		while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1)  
		{
			if(GetEntProp(ent, Prop_Data, "m_iDefaultOwner") == 0){
				//所有者無しCPをカウント
				iCount++;
				//使用していないはずなのでentCore[1]をバッファに使用する
				entCore[1] = ent;
			}
		}
		if(iCount != 1){
			PrintToServer("[CoreDefense] ERROR:CPを確保できませんでした。");
			return;
		}
		
		//CP座標を確保
		GetEntPropVector(entCore[1], Prop_Data, "m_vecOrigin", VecCore[1]);
		
		//ブロックをCPを基準に対象点を取る
		SubtractVectors(VecCore[0], VecCore[1], VecTemp);
		SubtractVectors(VecCore[1], VecTemp, VecCore[1]);
		//でもZ軸は同じな！
		VecCore[1][2] = VecCore[0][2];
		
		//座標に整形
		for(iCount=0;iCount<3;iCount++){
			VecCore[1][iCount] = RoundFloat(VecCore[1][iCount] / BLOCK_SIZE) * BLOCK_SIZE;
		}
		
		//Teamを設定
		if(entTeam[0] == TFTeam_Red){
			entTeam[1] = TFTeam_Blue;
		}
		else{
			entTeam[1] = TFTeam_Red;
		}
	}
	else if(iCount == 2){
		//ブロック座標を確保 VecCore[1]
		GetEntPropVector(entCore[1], Prop_Data, "m_vecOrigin", VecCore[1]);
	}
	
	//KeyValueに保存
	kvCore = CreateKeyValues("CoreDefense");
	for(iCount = 0; iCount < 2; iCount++){
		if(entTeam[iCount] == TFTeam_Red){
			KvJumpToKey(kvCore, "RedCore", true);
		}
		else if(entTeam[iCount] == TFTeam_Blue){
			KvJumpToKey(kvCore, "BlueCore", true);
		}
		KvSetVector(kvCore, "Position", VecCore[iCount]);
		//しっかり戻る必要がある
		KvGoBack(kvCore);
	}
	
	BuildPath(Path_SM, strPath, sizeof(strPath), "configs/CoreDefense/");
	if(!DirExists(strPath)){
		//フォルダが無いので作成する
		CreateDirectory(strPath, FPERM_O_EXEC);
	}
	
	GetCurrentMap(strName, sizeof(strName));
	Format(strPath, sizeof(strPath), "%s%s.txt", strPath, strName);
	
	if(!KeyValuesToFile(kvCore, strPath)){
		PrintToServer("[CoreDefense] ERROR:KeyValueファイルの保存に失敗しました。");
	}
	
	CloseHandle(kvCore);
}

//関数 初期化
public Func_Start(){

	new i;
	for(i=1;i<=MAXPLAYERS;i++){
		
		Func_BlockReset(i);
		
		g_Button[i] = 0;
		g_Set[i] = 0;
		g_block[i] = 0;
	}
	
	g_Locker = false;
	
	//Entityを停止させる
	Entity_Input("team_control_point_master","Disable");
	Entity_Input("team_control_point","Disable");
	Entity_Input("trigger_capture_area","Disable");
	Entity_Input("item_teamflag","Disable");
	Entity_Input("func_capturezone","Disable");
	Entity_Input("team_round_timer","Pause");
	
}

//関数 終了処理
public Func_End(){

	//全ブロックの破壊
	Func_Destroy();

	//リスタートする
	PrintToChatAll("[CoreDefense] Plugin disable. Game restart.");
	ServerCommand("mp_restartgame 3");
}

//関数 Coreブロックの設置
public Func_SetCore(){

	new Handle:kvCore = INVALID_HANDLE;
	new String:strPath[PLATFORM_MAX_PATH];
	new String:strMap[50];
	new Float:Pos[3];
	
	BuildPath(Path_SM, strPath, sizeof(strPath), "configs/CoreDefense/");
	GetCurrentMap(strMap, sizeof(strMap));
	Format(strPath, sizeof(strPath), "%s%s.txt", strPath, strMap);
	
	//ファイルが存在するかどうか
	if (FileExists(strPath) == false){
		PrintToServer("[CoreDefense] ERROR:Core設定ファイルがありません。");
		return;
	}
	
	//ハンドル作成　ルートはCoreDefense
	kvCore = CreateKeyValues("CoreDefense");
	//ファイルを読み込む
	if(FileToKeyValues(kvCore,strPath) == false){
		//ファイルを開くのに失敗した
		PrintToServer("[CoreDefense] ERROR:ファイルの読み込みに失敗しました。");
		CloseHandle(kvCore);
		return;
	}
	
	new i;
	for(i=2;i<4;i++){
		//ブロック作成
		new ent = CreateEntityByName("prop_dynamic");
		if(i == TFTeam_Red){
			if(!KvJumpToKey(kvCore, "RedCore", false)){
				PrintToServer("[CoreDefense] ERROR:RedのCore情報がありません。");
				CloseHandle(kvCore);
				AcceptEntityInput(ent, "Kill");
				return;
			}
			SetEntPropString(ent, Prop_Data, "m_iName", "cd_21");
		}
		else if(i == TFTeam_Blue){
			if(!KvJumpToKey(kvCore, "BlueCore", false)){
				PrintToServer("[CoreDefense] ERROR:BlueのCore情報がありません。");
				CloseHandle(kvCore);
				AcceptEntityInput(ent, "Kill");
				return;
			}
			SetEntPropString(ent, Prop_Data, "m_iName", "cd_31");
		}
		
		KvGetVector(kvCore, "Position", Pos);
		
		//モデル設定
		SetEntPropString(ent, Prop_Data, "m_ModelName", "models/CoreDefense/Core.mdl");
		//衝突判定を設定
		SetEntProp(ent, Prop_Data, "m_nSolidType",6);
		
		
		//Propをスポーンさせる
		if(DispatchSpawn(ent) == false){
			//何らかの理由でスポーンに失敗
			PrintToServer("[CoreDefense] ERROR:prop spawn faild");
			AcceptEntityInput(ent, "Kill");
			CloseHandle(kvCore);
			return;
		}
		//Propのヘルスを設定し、破壊可能にする
		SetEntProp(ent, Prop_Data, "m_iHealth", GetConVarInt(v_core_health));
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		
		SetEntityRenderColor(ent, 0, 255, 0, 100);
		TeleportEntity(ent, Pos, NULL_VECTOR, NULL_VECTOR);
		KvGoBack(kvCore);
	}
	CloseHandle(kvCore);
}
	
//関数 全ブロックの消去
public Func_Destroy(){
	
	//全ブロックの破壊
	new ent = -1;
	new String:strName[3];
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)  
	{
		GetEntPropString(ent, Prop_Data, "m_iName", strName, sizeof(strName));
		//cd_から始まるprop_dynamic全消去
		if(!strncmp(strName, "cd_", 3)){
			AcceptEntityInput(ent, "Kill");
		}
	}
}

//プレイヤー切断時
public OnClientDisconnect(int client){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	Func_BlockReset(client);
	g_Button[client] = 0;
	g_Set[client] = 0;
	g_block[client] = 0;
}

//関数 モデルDLリスト
public Func_ModelDL(){

	PrecacheModel("models/CoreDefense/Core.mdl");
	AddFileToDownloadsTable("models/CoreDefense/Core.mdl");
	AddFileToDownloadsTable("models/CoreDefense/Core.vvd");
	AddFileToDownloadsTable("models/CoreDefense/Core.phy");
	AddFileToDownloadsTable("models/CoreDefense/Core.dx90.vtx");
	AddFileToDownloadsTable("models/CoreDefense/Core.dx80.vtx");
	AddFileToDownloadsTable("materials/CoreDefense/myplastic.vmt");
	AddFileToDownloadsTable("materials/CoreDefense/myplastic.vtf");
	AddFileToDownloadsTable("materials/CoreDefense/myplastic_normal.vtf");
	
	PrecacheSound("weapons/wrench_hit_world.wav");
	PrecacheSound("weapons/teleporter_explode.wav");
	PrecacheSound("items/cart_explode.wav");
}	

//EntityにInputを送信
public Entity_Input(String:classname[], String:Input[]){
	
	int ent = -1;  
 
	while ((ent = FindEntityByClassname(ent, classname)) != -1)  
	{
		//PrintToServer("entity %s find",classname);
		int ref = EntIndexToEntRef(ent);
		AcceptEntityInput(ref, Input);
	}
	
}

//全フレーム実行…
new g_flag = 1;
public OnGameFrame(){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//実行フレーム数をとりあえず半分にしておく
	//少しでも処理が軽くなりますように
	g_flag = g_flag * -1;
	if(g_flag < 0){
		return;
	}
	
	new Float:angles[3];
	new buttons;
	
	new i;
	for(i=1;i<MaxClients;i++){
		if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
			
			//スパイはブロックを置けない(透明対策)
			if(TF2_GetPlayerClass(i) == TFClass_Spy){
				return ;
			}
			
			//入力確保
			buttons = GetClientButtons(i);
			
			//設置モード切替と設置は連続入力させない
			if(g_Button[i] == buttons &&
				((buttons & IN_ATTACK2) == IN_ATTACK2
				|| (buttons & IN_RELOAD) == IN_RELOAD)){
				return;
			}
			
			//設置モード切り替え
			if((buttons & IN_RELOAD) == IN_RELOAD){
				if(g_Set[i] == 0){
					g_Set[i] = 1;
				}
				else{
					g_Set[i] = 0;
				}
			}
			
			//ブロック設置関連処理
			if(g_Set[i] == 1){
				//仮ブロックを設置中でATTACK検出で設置する
				if((buttons & IN_ATTACK2) == IN_ATTACK2 && IsValidEntity(g_PropEnt[i]) == true){
					Func_BlockSpawn(i);
				}
				else{
					//それ以外なら仮ブロックを設置する
					GetClientEyeAngles(i, angles);
					Func_BlockCheck(i, angles);
				}
			}
			else{
				//ブロック設置モード終了
				Func_BlockReset(i);
			}
			//最終入力の確保
			g_Button[i] = buttons;
			
		}
	}
}

//関数 ブロック設置位置に仮ブロックを表示　実ブロックの設置が可能かのチェック
public Func_BlockCheck(int client, float angles[3]){

	new Float:Vec[3];
	new Float:CheckVec[3];
	new Float:Ang[3];
	new Handle:trTrace = INVALID_HANDLE;
	new TargetEnt;
	new flSizeMin[3];
	new flSizeMax[3];
	new i;

	//視線の先のブロックを確認-------------------------------------------------------------
	GetClientEyePosition(client, Vec);
	
	//トレース開始
	trTrace = TR_TraceRayFilterEx(Vec, angles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterProp);
	
	//トレース結果を取得
	if(TR_DidHit(trTrace) == true){
		TR_GetEndPosition(CheckVec, trTrace);	//衝突点の座標を取得
		TargetEnt = TR_GetEntityIndex(trTrace);	//衝突したEntityを取得
	}
	else{
		//トレースに失敗
		CloseHandle(trTrace);
		return;
	}
	//----------------------------------------------------------------------------------
	
	//一定距離以上離れている場合無効--------------------------------------------------------
	if(GetConVarInt(v_distance) <= GetVectorDistance(Vec, CheckVec)){
		Func_BlockReset(client);
		CloseHandle(trTrace);
		return;
	}
	//-----------------------------------------------------------------------------------
	
	//チェック終わったので入れ替え
	Vec = CheckVec;
	
	//衝突面に対する垂直ベクトルを取得
	TR_GetPlaneNormal(trTrace, Ang);
	//空白側のブロック座標を確認---------------------------------------------------------------
	if(TargetEnt == 0 || IsValidEntity(TargetEnt) == false){
		//地面に当たった場合、座標から探す
		for(i=0;i<3;i++){
			//ブロック半分分バックする
			Vec[i] += Ang[i] * (BLOCK_SIZE / 2.0);
			//0除算回避
			if(Vec[i] != 0.0){
				Vec[i] = Vec[i] / BLOCK_SIZE;
			}
			else{
				Vec[i] = 0.0;
			}
			//ブロック座標(Propの中央位置)
			Vec[i] = RoundFloat(Vec[i]) * BLOCK_SIZE;
		}
	}
	else{
		//ブロックに当たった場合、そのブロック座標から探す
		GetEntPropVector(TargetEnt, Prop_Data, "m_vecOrigin", CheckVec);
		for(i=0;i<3;i++){
			Vec[i] = CheckVec[i] + (Ang[i] * BLOCK_SIZE);
		}
	}
	
	CloseHandle(trTrace);
	//-------------------------------------------------------------------------------------
	
	//既に仮ブロックが設置されているかの確認-------------------------------------------------------
	//仮ブロックがまだ設置されていない
	if(IsValidEntity(g_PropEnt[client]) != true){
		//仮ブロック設置
		g_PropEnt[client] = CreateEntityByName("prop_dynamic");
		
		//SDKHook
		SDKHook(g_PropEnt[client], SDKHook_SetTransmit, OnSetTransmit);
		
		//モデル設定
		SetEntPropString(g_PropEnt[client], Prop_Data, "m_ModelName", "models/CoreDefense/Core.mdl");
		//衝突判定を設定
		SetEntProp(g_PropEnt[client], Prop_Data, "m_nSolidType",6);
		//衝突判定を消す
		AcceptEntityInput(g_PropEnt[client], "DisableCollision");
		
		//Propをスポーンさせる
		if(DispatchSpawn(g_PropEnt[client]) == false){
			//何らかの理由でスポーンに失敗
			PrintToServer("[CoreDefense]ERROR:prop spawn faild");
			Func_BlockReset(client);
			return;
		}
	}
	//-------------------------------------------------------------------------------------
	
	//座標の位置に出現させる
	TeleportEntity(g_PropEnt[client], Vec, NULL_VECTOR, NULL_VECTOR);
	
	//実ブロックの設置が可能かどうか確認する--------------------------------------------------------
	
	//トレースハルの範囲を設定する
	for(i=0;i<3;i++){
		flSizeMin[i] = (BLOCK_SIZE / -2.0) + 0.05;
		flSizeMax[i] = (BLOCK_SIZE / 2.0) - 0.05;
	}
	
	//トレースハル開始
	trTrace = TR_TraceHullFilterEx(Vec, Vec, flSizeMin, flSizeMax, CONTENTS_MOVEABLE, TraceEntityFilterPlayer);
	
	//何かとぶつかった 	もしくはブロック設置数が残っていない	Bonk状態である
	if(g_Hit > 0 || g_block[client] <= 0 || TF2_IsPlayerInCondition(client, TFCond_Bonked)){
		//色を設定(黒)
		SetEntityRenderColor(g_PropEnt[client], 50, 50, 50, 100);
		//点滅
		SetEntityRenderFx(g_PropEnt[client], RENDERFX_PULSE_SLOW_WIDE);
	}
	//ぶつからなかった(通常設定)
	else{
		//色を設定(チームカラー)		cd_から始まる名称で下1文字目はチーム、2文字目はコアかそうでないか
		if(GetClientTeam(client) == TFTeam_Blue){
			SetEntityRenderColor(g_PropEnt[client], 0, 0, 255, 100);
			SetEntPropString(g_PropEnt[client], Prop_Data, "m_iName", "cd_30");
		}
		else if(GetClientTeam(client) == TFTeam_Red){
			SetEntityRenderColor(g_PropEnt[client], 255, 0, 0, 100);
			SetEntPropString(g_PropEnt[client], Prop_Data, "m_iName", "cd_20");
		}
		else{
			//ゲーム中でない
			Func_BlockReset(client);
		}
		
		//半透明
		SetEntityRenderFx(g_PropEnt[client], RENDERFX_DISTORT);
	}
	
	g_Hit = -1;
	CloseHandle(trTrace);
	
}

//関数 実ブロックスポーン
public Func_BlockSpawn(int client){
	
	if(GetEntityRenderFx(g_PropEnt[client]) != RENDERFX_PULSE_SLOW_WIDE && g_block[client] > 0){
		//衝突判定を復活させる
		AcceptEntityInput(g_PropEnt[client], "EnableCollision");
		//点滅OFF
		SetEntityRenderFx(g_PropEnt[client], RENDERFX_NONE);
		//Propのヘルスを設定し、破壊可能にする
		SetEntProp(g_PropEnt[client], Prop_Data, "m_iHealth", GetConVarInt(v_health));
		SetEntProp(g_PropEnt[client], Prop_Data, "m_takedamage", 2);
		
		//ブロック数消費
		g_block[client] += -1;
		//HUD更新
		Func_Hud(client);
		//SDKUnhook
		SDKUnhook(g_PropEnt[client], SDKHook_SetTransmit, OnSetTransmit);
		//初期化
		g_PropEnt[client] = -1;
	}
	else{
		//設置できないのでエラー音を出す
		ClientCommand(client,"play replay/record_fail.wav");
	}
}

//関数 ブロック設置モード終了
public Func_BlockReset(int client){

	if(IsValidEntity(g_PropEnt[client]) == true && g_PropEnt[client] != 0){
		AcceptEntityInput(g_PropEnt[client],"Kill");
		//SDKUnhook
		SDKUnhook(g_PropEnt[client], SDKHook_SetTransmit, OnSetTransmit);
	}
	g_PropEnt[client] = -1;
}

//関数 HUD表示
public Func_Hud(int client){
	
	//所持ブロック
	new iBlocks = GetConVarInt(v_block);
	if(TF2_GetPlayerClass(client) == TFClass_Engineer){
		iBlocks++;
	}
	if(TF2_GetPlayerClass(client) == TFClass_Spy){
		iBlocks = 0;
	}
	SetHudTextParams(0.2, 0.9, 900.0, 255,255,255,255);
	ShowHudText(client, 1, "Blocks %d/%d",g_block[client],iBlocks);
	
	//コアHP
	new ent = -1;
	new String:strName[6];
	new iRedHealth;
	new iBlueHealth;
	
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)  
	{
		GetEntPropString(ent, Prop_Data, "m_iName", strName, sizeof(strName));
		//cd_から始まるprop_dynamic全消去
		if(!strncmp(strName, "cd_", 3) && !strncmp(strName[4], "1", 1)){
			if(!strncmp(strName[3], "2", 1)){
				iRedHealth = GetEntProp(ent, Prop_Data, "m_iHealth");
				if(iRedHealth < 0){
					iRedHealth = 0;
				}
			}
			else{
				iBlueHealth = GetEntProp(ent, Prop_Data, "m_iHealth");
				if(iBlueHealth < 0){
					iBlueHealth = 0;
				}
			}
		}
	}
	SetHudTextParams(0.55, 0.05, 900.0, 255, 0, 0, 255);
	ShowHudText(client, 2, "RedCore: %d", iRedHealth);
	SetHudTextParams(0.31, 0.05, 900.0, 0, 0, 255, 255);
	ShowHudText(client, 3, "BlueCore: %d", iBlueHealth);
	
}

//Filter トレース用フィルター Entity0、worldには必ずHitする？
public bool:TraceEntityFilterProp(entity, contentsMask){
	
	new String:strEntName[5];
	GetEntPropString(entity, Prop_Data, "m_iName", strEntName, sizeof(strEntName));
	
	if(!strncmp(strEntName, "cd_", 3)){
		return true;
	}
	return false;
}

//Filter トレース用フィルター プレイヤーのみHit させたいので無理やりやる
public bool:TraceEntityFilterPlayer(entity, contentsMask){
	//Hit条件でフラグを建てておく
	if(entity <= MaxClients && entity > 0){
		g_Hit = entity;
	}
	//戻り値が無視されているが一応残しておく
	return entity <= MaxClients && entity > 0;
}

//Filter トレース用フィルター WorldのみHit
public bool:TraceEntityFilterWorld(entity, contentsMask){
	return false;
}

//HookEvent チーム変更監視
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//チームが変更された場合EntIndexをリセット
	Func_BlockReset(GetClientOfUserId(GetEventInt(event, "userid")));
}

//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//関数 初期化
	Func_Start();
	
	//全ブロックの破壊
	Func_Destroy();
	
	//Coreブロックの設置
	Func_SetCore();
	
	//HUD表示
	new i;
	for(i=1;i<=MaxClients;i++){
		if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
			Func_Hud(i);
		}
	}
	
	//ロッカー使用可
	g_Locker = true;
	
}

//HookEvent アイテム取得時
public OnItemPikup(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	new String:strName[20];
	new iBlocks = GetConVarInt(v_block);
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetEventString(event, "item", strName, sizeof(strName));
	
	if(StrEqual(strName, "ammopack_small")){
		g_block[client] += 1;
	}
	else if(StrEqual(strName, "ammopack_medium")){
		g_block[client] += 2;
	}
	else if(StrEqual(strName, "ammopack_large")){
		g_block[client] += 3;
	}
	else{
		return;
	}
	
	//エンジニアは1つ多く持てる
	if(TF2_GetPlayerClass(client) == TFClass_Engineer){
		iBlocks++;
	}
	//スパイはブロックを持てない
	if(TF2_GetPlayerClass(client) == TFClass_Spy){
		iBlocks = 0;
	}
	
	if(g_block[client] > iBlocks){
		g_block[client] = iBlocks;
	}
	
	//HUD更新
	Func_Hud(client);
	
}

//HookEvent 死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//デッドリンガーは除外する
	if(GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER == TF_DEATHFLAG_DEADRINGER){
		return;
	}
	
	//EntIndexをリセット
	Func_BlockReset(GetClientOfUserId(GetEventInt(event, "userid")));
	g_Set[GetEventInt(event, "userid")] = 0;
}

//HookEvent スポーン時
public OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_block[client] = 0;
	
	//何故かHUD表示がされないのでタイマーを仕掛ける
	CreateTimer(0.1, Timer_EnableHud,client);
}

//Timer スポーン後HUD表示
public Action:Timer_EnableHud(Handle:timer, any:client){
	Func_Hud(client);
}

//HookEvent CPアンロック時
public OnUnlock(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	g_Locker = false;
}

//HookEvent ロッカー使用時
public OnUseLocker(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0 || g_Locker == false){
		return;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_block[client] <= 0 && TF2_GetPlayerClass(client) != TFClass_Spy){
		g_block[client]++;
	}
	//HUD更新
	Func_Hud(client);
}

//Hook Propにダメージが与えられた時に実行される 
public Action:OnTakeDamage(const char[] output, int caller, int activator, float delay){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	new String:strTeam[6];
	new Float:Pos[3];
	
	//ブロックの情報を取得
	GetEntPropVector(caller, Prop_Data, "m_vecOrigin", Pos);
	new iHealth = GetEntProp(caller, Prop_Data, "m_iHealth");
	GetEntPropString(caller, Prop_Data, "m_iName", strTeam, sizeof(strTeam));
	new iColor = RoundFloat((iHealth * 1.0) / GetConVarInt(v_health) * 155.0) + 100;
	
	//ダメージに応じて色を変える	名称1文字目はチーム、2文字目はコアか通常ブロックか
	if(!strncmp(strTeam, "cd_", 3)){
		if(!strncmp(strTeam[4], "1", 1)){
			iColor = RoundFloat((iHealth * 1.0) / GetConVarInt(v_core_health) * 205.0) + 50;
			SetEntityRenderColor(caller, 0, iColor, 0, iColor);
			EmitAmbientSound("weapons/teleporter_explode.wav", Pos, _, SNDLEVEL_MINIBIKE);
		}
		else if(!strncmp(strTeam[3], "3", 1)){
			SetEntityRenderColor(caller, 0, 0, iColor, iColor);
		}
		else if(!strncmp(strTeam[3], "2", 1)){
			SetEntityRenderColor(caller, iColor, 0, 0, iColor);
		}
		else{
			return;
		}

		//ヒット音鳴らす
		EmitAmbientSound("weapons/wrench_hit_world.wav", Pos);
	}
	
	//HUD更新
	new i;
	for(i=1;i<=MaxClients;i++){
		if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
			Func_Hud(i);
		}
	}
}

//Hook Propが破壊された時に実行される OnBreak
public Action:OnBreak(const char[] output, int caller, int activator, float delay){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	new Float:Pos[3];
	new String:strTeam[6];	
	
	//ブロックの情報を取得
	new iHealth = GetEntProp(caller, Prop_Data, "m_iHealth");
	GetEntPropString(caller, Prop_Data, "m_iName", strTeam, sizeof(strTeam));
	GetEntPropVector(caller, Prop_Data, "m_vecOrigin", Pos);
	
	if(iHealth <= 0){
		
		new ent = CreateEntityByName("env_explosion");
		DispatchSpawn(ent);
		TeleportEntity(ent, Pos, NULL_VECTOR, NULL_VECTOR);
		
		if(!strncmp(strTeam[4], "1", 1)){
			//爆発Entityにダメージ判定を追加
			DispatchKeyValue(ent, "iMagnitude", "9999");
			DispatchKeyValue(ent, "iRadiusOverride", "400");
			//爆発エフェクトを表示させる
			new entSprite = CreateEntityByName("info_particle_system");
			TeleportEntity(entSprite, Pos, NULL_VECTOR, NULL_VECTOR);
			DispatchKeyValue(entSprite, "effect_name", "cinefx_goldrush");//呼び出すパーティクルを指定
			DispatchSpawn(entSprite);	
			ActivateEntity(entSprite);
			AcceptEntityInput(entSprite, "start");
			//爆発音
			EmitSoundToAll("items/cart_explode.wav");
			
			//勝利させる
			//現在のフラグを保存する
			new forcewin_flag = GetCommandFlags("mp_forcewin");
			//強制的にフラグを落とす(ビットを反転させる→フラグを上げる(反転してるから下がる)→ビットを反転させる)
			new tempFlag = ~GetCommandFlags("mp_forcewin")|FCVAR_CHEAT;
			SetCommandFlags("mp_forcewin",~tempFlag);
			
			if(!strncmp(strTeam[3], "2", 1)){
				//ラウンドを強制的に終了させる
				ServerCommand("mp_forcewin %d",TFTeam_Blue);
			}
			else{
				ServerCommand("mp_forcewin %d",TFTeam_Red);
			}
			
			//HUD更新
			new i;
			for(i=1;i<=MaxClients;i++){
				if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
					Func_Hud(i);
				}
			}
			
			//直後に権限を戻そうとすると実行されないのでタイマーで遅延させる
			CreateTimer(1, Cmd_EndCommanFlag,forcewin_flag);
		}
		AcceptEntityInput(ent,"Explode");
	}
}

//Timer コマンド実行フラグの修正
public Action:Cmd_EndCommanFlag(Handle:timer, any:flag){
	SetCommandFlags("mp_forcewin",flag);
}

//SDKHook Prop表示時？
public Action:OnSetTransmit(entity, client){
	if(entity != g_PropEnt[client]){
		return Plugin_Handled;
	}
	return Plugin_Continue;
}