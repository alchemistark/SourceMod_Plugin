#include <sourcemod>
#include <tf2_stocks>

//有効にするMGEマップ名
#define MGE_MAP "mge_training_v8_beta4b"

public Plugin:myinfo = 
{
	name = "[TF2]MGE Limit",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "MGEの縛りルール",
	version = "1.0.2",
	url = ""
}

new Handle:v_enable = INVALID_HANDLE;	//プラグインの有効無効
new Handle:v_mode = INVALID_HANDLE;	//ダメージを受けない・トドメをさせない の切替
new Handle:v_damage = INVALID_HANDLE;	//バスケのハンデに使うダメージ値
new Handle:v_stuntime = INVALID_HANDLE;	//バスケのハンデに使うスタン時間
new Handle:v_stunspeed = INVALID_HANDLE;	//バスケのハンデに使うスタン時の速度

new g_enable[MAXPLAYERS+1];	//有効状態かどうか
new g_damage[MAXPLAYERS+1];	//バスケのハンデに使うダメージ値

//動作モード
enum{
	ML_MODE_NONE = 0,
	ML_MODE_SPY_1,
	ML_MODE_SPY_2,
	ML_MODE_SNIPER,
	ML_MODE_ENGINEER,
	ML_MODE_SOLDIER
}

//プラグイン起動時
public OnPluginStart(){

	//cvar
	v_enable = CreateConVar("sm_ml_enable", "0", "0:disable 1:enable");
	v_mode = CreateConVar("sm_ml_mode", "0", "0:ダメージを受けない ANY:トドメをさせない(ヘルスが0になると設定した値までヘルスを回復させる)");
	v_damage = CreateConVar("sm_ml_damage", "200", "バスケのハンデでインテルをドロップするダメージ値");
	v_stuntime = CreateConVar("sm_ml_stuntime", "4", "バスケのハンデに使うスタン時間");
	v_stunspeed = CreateConVar("sm_ml_stunspeed", "0.8", "バスケのハンデに使うスタン時の速度");
	
	//event
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_death", OnPlayerDeath);
	AddCommandListener (OnPlayerChangeclass, "joinclass");
	
	//翻訳ファイル
	LoadTranslations("mgelimit.phrases");
	
}

//マップ開始時
//マップがMGEでなければ無効化する
public OnMapStart(){

	new String:strMapName[50];
	GetCurrentMap(strMapName,sizeof(strMapName));
	if(StrEqual(strMapName,MGE_MAP) == true){
		SetConVarInt(v_enable,1);
	}
	else{
		SetConVarInt(v_enable,0);
	}
}

//EventHook チーム変更処理(切断を含む)
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_enable[client] = 0;
	g_damage[client] = 0;
}

//EventHook クラス変更監視
public Action:OnPlayerChangeclass(client, const String:command[], argc){

	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}

	new Float:vec[3];
	new bool:blArena;
	
	new String:strClass[10];
	new String:strTranslation[255];
	GetCmdArg(1,strClass, sizeof(strClass));
	
	//現在位置を比較し、BBallArenaに居るか確認する
	GetClientAbsOrigin(client, vec);
	//もういい力技する
	if(12800.00 < vec[0] && vec[0] < 13910.00 &&
	-4471.00 < vec[1] && vec[1] < -2470.00 &&
	-950.00 < vec[2] && vec[2] < -700.00){
		blArena = true;
	}
	else{
		blArena = false;
	}
	
	new Handle:m_menu = CreateMenu(Menu_limit);
	//SetMenuTitle(m_menu, "Enable MGE Limit Mode?");
	Format(strTranslation, sizeof(strTranslation), "%T", "MenuTitle", client);
	SetMenuTitle(m_menu, strTranslation);
	SetMenuExitButton(m_menu,false);

	if(StrEqual(strClass,"spy")){
		IntToString(ML_MODE_SPY_1,strClass,sizeof(strClass));
		Format(strTranslation, sizeof(strTranslation), "%T", "Spy_1", client);
		AddMenuItem(m_menu, strClass, strTranslation, ITEMDRAW_DEFAULT);
		Format(strTranslation, sizeof(strTranslation), "%T", "Spy_2", client);
		IntToString(ML_MODE_SPY_2,strClass,sizeof(strClass));
	}
	else if(StrEqual(strClass,"sniper")){
		IntToString(ML_MODE_SNIPER,strClass,sizeof(strClass));
		Format(strTranslation, sizeof(strTranslation), "%T", "Sniper", client);
	}
	else if(StrEqual(strClass,"engineer")){
		IntToString(ML_MODE_ENGINEER,strClass,sizeof(strClass));
		Format(strTranslation, sizeof(strTranslation), "%T", "Engineer", client);
	}
	else if(StrEqual(strClass,"soldier") && blArena){
		IntToString(ML_MODE_SOLDIER,strClass,sizeof(strClass));
		Format(strTranslation, sizeof(strTranslation), "%T", "Soldier", client);
	}
	//対象クラス以外は終了させる
	else{
		CloseHandle(m_menu);	//使用していないのでhandleを閉じる
		g_enable[client] = 0;
		g_damage[client] = 0;
		return Plugin_Continue;
	}
	
	AddMenuItem(m_menu, strClass, strTranslation, ITEMDRAW_DEFAULT);
	
	IntToString(ML_MODE_NONE,strClass,sizeof(strClass));
	Format(strTranslation, sizeof(strTranslation), "%T", "MenuDisable", client);
	AddMenuItem(m_menu, strClass, strTranslation, ITEMDRAW_DEFAULT);
	DisplayMenu(m_menu,client,20);
	
	return Plugin_Continue;
}	

public Menu_limit(Handle:menu, MenuAction:action, param1, param2) {
	switch(action){	//MenuAction チェック
			case MenuAction_Select:{
				//param1:client index param2:item number
				new String:strSection[2];
				new String:strTranslation[200];
				GetMenuItem(menu, param2, strSection, sizeof(strSection));
				//モードに入っている
				if(StringToInt(strSection) != ML_MODE_NONE){
					//けどもう入ってるならスルーする
					if(g_enable[param1] != StringToInt(strSection)){
						Format(strTranslation, sizeof(strTranslation), "%T", "Enable", param1);
						PrintToChat(param1, strTranslation);
					}
				}
				//モードから抜けている
				else{
					//元から入ってない
					if(g_enable[param1] != ML_MODE_NONE){
						Format(strTranslation, sizeof(strTranslation), "%T", "Disable", param1);
						PrintToChat(param1, strTranslation);
					}
				}
				g_enable[param1] = StringToInt(strSection);
				g_damage[param1] = 0;
			}
			//タイムアウトがある
			case MenuAction_Cancel:{
				g_enable[param1] = 0;
				g_damage[param1] = 0;
			}
			//メニュー処理が終了した
			case MenuAction_End:{
				CloseHandle(menu);	//終了したらハンドルを閉じておく
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}

//HookEvent 被ダメ時
public OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	new weaponid = GetEventInt(event,"weaponid");
	new custom = GetEventInt(event, "custom");
	new health = GetEventInt(event, "health");
	new flag = 0;
	new iHealth;
	new OverHeal;
	
	//スパイかつバックスタブである(ML_MODE_SPY_1が有効中)
	if(g_enable[attacker] == ML_MODE_SPY_1 && custom == 2){
		flag = 1;
	}
	//ML_MODE_SPY_2 スタブ、リボルバーのダメージは通る(ナイフ以外とする)
	else if(g_enable[attacker] == ML_MODE_SPY_2){
		if(custom == 2 || weaponid != TF_WEAPON_KNIFE){
			flag = 1;
		}
	}
	//スナイパーかつヘッドショットである(ML_MODE_SNIPERが有効中)
	//ヒットマンズ・ヒートメーカーはcustomが51
	else if(g_enable[attacker] == ML_MODE_SNIPER && (custom == 1 || custom == 51)){
		flag = 1;
	}
	//ダメージを受けたのはハンデ中のソルである(ML_MODE_SOLDIERが有効中)
	else if(g_enable[client] == ML_MODE_SOLDIER){
		flag = 0;
	}
	//対象外(エンジニアの攻撃はブロックされない ML_MODE_NONEを含む) ソルジャーも攻撃は関係ない
	else if(g_enable[attacker] == ML_MODE_NONE || g_enable[attacker] == ML_MODE_ENGINEER || g_enable[attacker] == ML_MODE_SOLDIER){
		flag = 1;
	}
	
	//どれにも一致しない場合、ダメージはブロックされる。
	//以下ダメージをブロックする処理
	
	if(flag == 0){
		//モードがダメージ禁止
		if(GetConVarInt(v_mode) == 0){
			//現在のヘルス値とダメージ値を足しておく　eventの"health"は0以下にならないので使ってはならない
			//GetClientHealthはマイナスまでカウントされるのでこちらを使う
			iHealth = GetClientHealth(client) + GetEventInt(event, "damageamount");
		}
		//モードがキル禁止(指定値まで回復)
		else{
			if(health != 0){
				//キルされたのでなければそのままダメージを通す
				return Plugin_Continue;
			}
			iHealth = GetConVarInt(v_mode);
			OverHeal = RoundToNearest(GetEntProp(client, Prop_Data, "m_iMaxHealth") * 1.5);
			if(iHealth > OverHeal){
				//指定値がオーバーヒールの最大値を超えていた場合、修正する
				iHealth = OverHeal;
			}
		}
		
		//回復する
		SetEntityHealth(client, iHealth);
		
		//以下バスケのハンデ処理
		if(g_enable[client] == ML_MODE_SOLDIER){
			if(GetConVarInt(v_mode) == 0){
				g_damage[client] += GetEventInt(event, "damageamount");
				if(g_damage[client] > GetConVarInt(v_damage)){
					//インテルを落とす
					FakeClientCommandEx(client,"dropitem");
					PrintHintText(client,"Stun!");
					TF2_StunPlayer(client,GetConVarFloat(v_stuntime),GetConVarFloat(v_stunspeed),TF_STUNFLAG_SLOWDOWN,0);
					g_damage[client] = 0;
				}
			}
			else if(health == 0){
				//インテルを落とす
				FakeClientCommandEx(client,"dropitem");
				PrintHintText(client,"Stun!");
				SetEntityHealth(client, GetConVarInt(v_damage));
				TF2_StunPlayer(client,GetConVarFloat(v_stuntime),GetConVarFloat(v_stunspeed),TF_STUNFLAG_SLOWDOWN,0);
			}
		}
	}
	else{
		//普通にダメージが通っているならダメージ記録を破棄
		g_damage[client] = 0;
	}
	
	return Plugin_Continue;
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	//デッドリンガーは除外する
	if(GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER == TF_DEATHFLAG_DEADRINGER){
		return Plugin_Continue;
	}
	
	//キルした人
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	
	//死んだ人
	new die_client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)	//名前からエンティティを探す
	{
		Cmd_entkill(ent,attacker,die_client);
	}
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)	//名前からエンティティを探す
	{
		Cmd_entkill(ent,attacker,die_client);
	}
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)	//名前からエンティティを探す
	{
		Cmd_entkill(ent,attacker,die_client);
	}
	
	return Plugin_Continue;
}

public Cmd_entkill(int ent,int client1, int client2){

	new Owner;
	
	//デバイスの所有者が機能を有効にしていたら破壊する
	Owner = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
	if(g_enable[Owner] == ML_MODE_ENGINEER && (Owner == client1 || Owner == client2)){
		AcceptEntityInput(ent, "Kill");
	}
}