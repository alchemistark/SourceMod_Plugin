#include <sourcemod>
#include <TF2>
#include <tf2_stocks>
#include <sdktools>

/*

サーバー温め中に全員でDMするプラグイン

・5CP、KOTH
CP(5CPの場合センターCP)周辺で即スポーンする

・他マップ
無効
そのうちPLやADの最終CP基準もできるようにしたい

対象CPから一定距離離れかつ一定距離以内でスポーンする
とは言ってもセンターCPのpropから少し離れるぐらいでいいと思う
スポーンしたらCPの方を向く　angleは水平で良い

オバヒは与える

DMに参加したくない人は無敵になれる(ただし与ダメも無くなる)
無敵状態はエフェクトで確認可能に

*/

#define SPAWN_RANGE 200

new Handle:v_enable = INVALID_HANDLE;
new Handle:v_range_max = INVALID_HANDLE;
new Handle:v_range_min = INVALID_HANDLE;
new g_ent = -1;


public Plugin:myinfo = 
{
	name = "[TF2]Waiting DeathMatch",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "簡易デスマッチ　プレイヤー待ち向け",
	version = "",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){

	//cmd
	RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	RegAdminCmd("sm_r", Cmd_respawn, 0, "リスポーンする");

	//cvar
	v_enable = CreateConVar("sm_wdm_enable", "0", "WDMモードのOnOffを切り替える");
	v_range_max = CreateConVar("sm_wdm_rangemax", "700", "スポーン範囲(最大値)");
	v_range_min = CreateConVar("sm_wdm_rangemin", "200", "スポーン範囲(最低値)");
	
	//hook
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", OnPlayerSpawned, EventHookMode_Post);
	HookEvent("teamplay_round_active", OnRoundStart);
	
	HookConVarChange(v_enable, OnConVarChanged_enable);
	HookConVarChange(v_range_max, OnConVarChanged_range);
	HookConVarChange(v_range_min, OnConVarChanged_range);
}

//cmd デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	
	new String:strName[255];
	
	GetPluginFilename(INVALID_HANDLE, strName, sizeof(strName));
	ServerCommand("sm plugins reload %s", strName);
	GetPluginInfo(INVALID_HANDLE, PlInfo_Name, strName, sizeof(strName));
	ReplyToCommand(client,"reload plugin '%s'", strName);
}

//cmd エリア外スポーンとかした時用
public Action:Cmd_respawn(client, args){
	if(GetConVarInt(v_enable) == 0){
		return;
	}
	TF2_RespawnPlayer(client);
}

//関数 EntityにInputを送信
public Entity_Input(String:classname[], String:Input[]){
	
	new ent = -1;  
 
	while((ent = FindEntityByClassname(ent, classname)) != -1){
		new ref = EntIndexToEntRef(ent);
		AcceptEntityInput(ref, Input);
	}
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

	new i;
	
	//プラグインが有効化された
	if(StringToInt(newValue) == 1){
		
		//初期化処理
		Func_Start();
		
	}
	//プラグインが無効化された
	else if(StringToInt(newValue) == 0){
		//Entityを動作させる
		Entity_Input("team_control_point_master","Enable");
		Entity_Input("team_control_point","Enable");
		Entity_Input("trigger_capture_area","Enable");
		Entity_Input("func_capturezone","Enable");
		
		new ent = -1;
		if(FindEntityByClassname(ent,"tf_logic_koth") == -1){
			//kothの場合タイマーは止めたままにしておく
			Entity_Input("team_round_timer","Resume");
		}
		
		//変数のリセット
		g_ent = -1;
		
		//スポーン処理
		for(i = 1;i<MaxClients;i++){
			if(IsClientConnected(i) == true && IsClientInGame(i) == true && GetClientTeam(i) >= 2){
				//全員リスポーンさせる
				TF2_RespawnPlayer(i);
			}
		}
	}
	//不正な値の場合元に戻す
	else{
		PrintToServer("[WDM]ERROR:値が不正です。");
		SetConVarInt(convar,StringToInt(oldValue));
	}
	
	return true;
}

//ConVar変更時（スポーン範囲変更時）
public OnConVarChanged_range(ConVar convar, const char[] oldValue, const char[] newValue){

	new String:strName[20];
	new iMax;
	new iMin;
	
	//数値以外が入力された or 負の値が入力された
	if((StringToInt(newValue) == 0 && StrEqual(newValue, "0") == false)
		|| StringToInt(newValue) < 0){
		PrintToServer("[WDM]ERROR:値が不正です。");
		SetConVarInt(convar,StringToInt(oldValue));
		return false;
	}
	
	//どちらのConvarか確認用
	GetConVarName(convar, strName, sizeof(strName));
	
	if(StrEqual(strName, "sm_wdm_rangemax")){
		iMax = StringToInt(newValue);
		iMin = GetConVarInt(v_range_min);
	}
	else{ //else if(StrEqual(strName, "sm_wdm_rangemin"){
		iMax = GetConVarInt(v_range_max);
		iMin = StringToInt(newValue);
	}
	
	//差分を確認
	if((iMax - iMin) < SPAWN_RANGE){
		PrintToServer("[WDM]スポーン範囲は最低%d確保するようにしてください。",SPAWN_RANGE);
		SetConVarInt(convar, StringToInt(oldValue));
		return false;
	}
	
	return true;
}

//関数 マップ確認、基準CPの確保
public Func_CPCheck(){

	//マップを確認する　エラーは-1
	
	new ent = -1;
	new eTemp = -1;
	new eCP = -1;
	new iOwner[4];
	new iTemp;
	new String:strFinalCP[255];
	new String:strProp[255];
	//new i;
	
	//item_teamflagが存在したならばCTFである
	while((ent = FindEntityByClassname(ent,"item_teamflag")) != -1)
	{
		PrintToServer("[WDM]ERROR:対応していないマップです。(マップがCTFです。)");
		return -1;
	}
	
	//tf_logic_multiple_escortが存在したならばPLRである
	while((ent = FindEntityByClassname(ent,"tf_logic_multiple_escort")) != -1)
	{
		PrintToServer("[WDM]ERROR:対応していないマップです。(マップがPLRです。)");
		return -1;
	}
	
	//マップがPL、A/Dの場合
	while((ent = FindEntityByClassname(ent,"team_control_point_round")) != -1){
		//各ラウンドのCPの所有者を確認
		GetEntPropString(ent, Prop_Data, "m_iszCPNames", strProp, sizeof(strProp));
		new i;
		//現在のマップの最終CP名を確保
		while((i = BreakString(strProp[i], strFinalCP, sizeof(strFinalCP))) != -1){
			Format(strProp, sizeof(strProp), "%s", strProp[i]);
		}
		//名前から最終CPのEntを確保
		while((eTemp = FindEntityByClassname(eTemp,"team_control_point")) != -1){
			GetEntPropString(eTemp, Prop_Data, "m_iName", strProp, sizeof(strProp));
			if(StrEqual(strProp, strFinalCP)){
				//キャプチャーされてないCPにおいて
				if(GetEntProp(eTemp, Prop_Data, "m_iDefaultOwner") == GetEntProp(eTemp, Prop_Send, "m_iTeamNum")){
					//プライオリティのより高いCPのent番号を確保
					if(iTemp <= (iTemp = GetEntProp(ent, Prop_Data, "m_nPriority"))){
						eCP = eTemp;
					}
				}
			}
		}
	}
	
	//PL,A/Dの対象CPがある場合、終了
	if(eCP != -1){
		return eCP;
	}
	
	//それ以外のマップ
	while((ent = FindEntityByClassname(ent,"team_control_point")) != -1)
	{
		//各チームの所有CP数をカウント
		iTemp = GetEntProp(ent, Prop_Data, "m_iDefaultOwner");
		iOwner[iTemp]++;
		//所有者無しCPは対象CPの可能性が高いので確保(kothもしくは普通の5cp系マップ）
		if(iTemp == 0){
			eCP = ent;
		}
		//一番Index値の高いCPは最終CPの可能性が高い
		if(IsValidEntity(eTemp)){
			if(GetEntProp(ent, Prop_Data, "m_iPointIndex") > GetEntProp(eTemp, Prop_Data, "m_iPointIndex")){
			eTemp = ent;
			}
		}
		else{
			eTemp = ent;
		}
	}
	
	//所有者無しCPが1つの場合、それで確定
	if(iOwner[TFTeam_Unassigned] == 1){
		return eCP;
	}
	else if(iOwner[TFTeam_Unassigned] > 1){
		//所有者無しCPが複数あるマップは対象外とする　オレンジとか
		return -1;
	}
	
	//CPが存在しない
	if(iOwner[TFTeam_Red] == 0 && iOwner[TFTeam_Blue] == 0){
		return -1;
	}
	
	//全てのCPを片方のチームが所有している場合A/Dと判断し、Indexの一番大きいCPを対象とする
	if(iOwner[TFTeam_Red] == 0 || iOwner[TFTeam_Blue] == 0){
		return eTemp;
	}
	
	//マップ不明
	return -1;
}

//関数 初期化処理
public Func_Start(){
	//マップとCPを確認
	g_ent = Func_CPCheck();
	if(g_ent == -1){
		PrintToChatAll("[WDM]ERROR:プラグインを有効化できませんでした。");
		SetConVarInt(v_enable,0,false,false);
		return;
	}
	
	//Entityを停止させる
	Entity_Input("team_control_point_master","Disable");
	Entity_Input("team_control_point","Disable");
	Entity_Input("trigger_capture_area","Disable");
	Entity_Input("func_capturezone","Disable");
	Entity_Input("team_round_timer","Pause");
	

	//スポーン処理
	new i;
	for(i = 1;i<MaxClients;i++){
		if(IsClientConnected(i) == true && IsClientInGame(i) == true && GetClientTeam(i) >= 2){
			//全員リスポーンさせる
			TF2_RespawnPlayer(i);
		}
	}
}

//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	//初期化処理
	Func_Start();
}
	
//HookEvent スポーン時
public OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	while(!Func_Spawn(client)){
		//PrintToServer("[WDM]ERROR:トレースに失敗しました。再試行します。");
	}
	
	//オバヒさせる
	SetEntityHealth(client, RoundToNearest(GetEntProp(client, Prop_Data, "m_iMaxHealth") * 1.5));
	ClientCommand(client, "playgamesound Item.Materialize");

	return true;
}

//スポーンさせる
public Func_Spawn(int client){

	//トレースが一番外のボックスの外側から開始→TR_DidHitがfalse
	//トレースがマップの外側で一番外のボックスの内側から開始→スポーン地点が不正でTeleportEntityがエラー

	new Float:vecCP[3];
	new Float:angTR[3] = {90.0,0.0,0.0};
	new Float:posTR[3];
	new Float:flSizeMin[3] = {-24.0,-24.0,-40.0};
	new Float:flSizeMax[3] = {24.0,24.0,40.0};
	new Float:flRangeMax = GetConVarFloat(v_range_max);
	new Float:flRangeMin = GetConVarFloat(v_range_min);
	new Float:flRand;
	new Handle:trTrace = INVALID_HANDLE;
	new String:strEntName[255];
	
	//基準CPの座標を確認
	GetEntPropVector(g_ent, Prop_Data, "m_vecOrigin", vecCP);
	
	//基準CPを元に指定範囲内でランダムにスポーン地点を決定
	new i;
	new iFlag;
	do{
		for(;i<3;i++){
			flRand = GetURandomFloat() * (flRangeMax*2);	//範囲内のランダム値を取得(前後に最大値確保の為倍がけ)
			flRand = flRand - flRangeMax;			//＋－範囲内に直す為最大値の値を引く

			posTR[i] = vecCP[i] + flRand;	//CPを基準にランダム値分座標をずらす
		}
		if(FloatAbs(flRand) < flRangeMin){	//CPから最低距離以上離れているか？ 小さければやり直し
			iFlag++;
		}
	}
	while(iFlag == 3);		
	
	//トレース開始
	trTrace = TR_TraceRayFilterEx(posTR, angTR, MASK_PLAYERSOLID, RayType_Infinite,TraceEntityFilterPlayer);
	
	//トレース結果を取得
	if(TR_DidHit(trTrace) == true){
		TR_GetEndPosition(posTR, trTrace);
	}
	else{
		//トレースに失敗
		CloseHandle(trTrace);
		return false;
	}
	
	//トレースで地下世界まで行った(トレースにより範囲外に出た)
	if((vecCP[2] - flRangeMax) > posTR[2]){
		CloseHandle(trTrace);
		return false;
	}
	
	//トレース終了
	CloseHandle(trTrace);
	
	//トレースハル開始
	trTrace = TR_TraceHullEx(posTR, posTR, flSizeMin, flSizeMax, MASK_SOLID);
	
	//着地点が死亡床もしくはスポーンルームだったらやり直し
	if(TR_GetEntityIndex(trTrace) != -1){
		GetEntityClassname(TR_GetEntityIndex(trTrace), strEntName, sizeof(strEntName));
		if(StrEqual(strEntName, "trigger_hurt") == true || StrEqual(strEntName, "func_respawnroom") == true)
		{
			//スポーン不許可
			CloseHandle(trTrace);
			return false;
		}
	}
	
	//トレースハル終了
	CloseHandle(trTrace);
	
	//出現位置確定、トレースハルの為ボックスの中央位置をズラす
	//出現位置補正+20　ボックス位置補正+40 ボックスサイズは48.48.80
	posTR[2] += 60.0;
	
	//トレースハル開始
	trTrace = TR_TraceHullEx(posTR, posTR, flSizeMin, flSizeMax, MASK_PLAYERSOLID);
	if(TR_DidHit(trTrace) == true){
		//スポーン不可　スタックする
		CloseHandle(trTrace);
		return false;
	}
	
	//トレースハル終了
	CloseHandle(trTrace);
	
	//ボックス位置補正-40
	posTR[2] += -40.0;
	
	//2点間の角度を取得 angTRを再利用する
	angTR[0] = angTR[2] = 0.0;	//ピッチ(上下角)とロール(回転角)は変更しない
	angTR[1] = RadToDeg(ArcTangent2(vecCP[1] - posTR[1], vecCP[0] - posTR[0]));
	
	//スポーン位置にワープ
	TeleportEntity(client, posTR, angTR, NULL_VECTOR);
	
	return true;
}

//トレース用フィルター
//true でhit falseで通過？
public bool:TraceEntityFilterPlayer(entity, contentsMask){
	//フィルターCB内では使えない関数が多数ある
	//PrintToServer等
	
	// new i;
	// for(i = 1;i<MaxClients;i++){
		// if(IsClientConnected(i) == true && IsClientInGame(i) == true && GetClientTeam(i) >= 2){
			// if(entity == i){
				// return false;
			// }
		// }
	// }
	// return true;
	
	//entityがMaxClientsより大きい（プレイヤー予約枠ではない）か、0である場合trueを返す
	//この場合、自分を含めプレイヤーはトレース対象にならない
	//他プレイヤーをトレースで探す場合、自分のみ通過させる
	return entity > MaxClients || !entity;
}

//HookEvent 死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//プラグイン有効時のみ
	if(GetConVarInt(v_enable) == 0){
		return;
	}

	//デッドリンガーは除外する
	if(GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER == TF_DEATHFLAG_DEADRINGER){
		return;
	}
	
	//強制スポーン
	CreateTimer(0.2, Cmd_Respawn, GetClientOfUserId(GetEventInt(event,"userid")));
}

//スポーンタイマー
public Action:Cmd_Respawn(Handle:timer, any:client){
	//時間経過後、スポーンする
	if(IsClientInGame(client) == true){
		TF2_RespawnPlayer(client);
	}
}
