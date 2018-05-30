#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2items_giveweapon>

new Handle:v_spec = INVALID_HANDLE;
new Handle:v_spawn = INVALID_HANDLE;
new Handle:v_debug = INVALID_HANDLE;

new g_ent = -1;

public Plugin:myinfo = 
{
	name = "AMG_plugins",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "自作の小ネタ集",
	version = "1.0",
	url = ""
}

/*
小ネタ集

実装
・常に強制スポーン
・強制ラウンド終了
・観戦発言強制表示

未実装
・強制rcon →危険？

*/


//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	RegAdminCmd("sm_win", Cmd_win, Admin_Kick, "ラウンドを強制的に終了します");
	RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	RegAdminCmd("sm_health", Cmd_health, 0, "ヘルスの最大値を変更する");
	RegAdminCmd("sm_debug", Cmd_debug, 0, "デバッグコマンド");
	RegAdminCmd("sm_debug1", Cmd_debug1, 0, "デバッグコマンド");
	RegAdminCmd("sm_save", Cmd_telesave, 0, "tele");
	RegAdminCmd("sm_load", Cmd_teleload, 0, "tele");
	RegAdminCmd("sm_menutest", Cmd_menu, 0, "tele");
	RegAdminCmd("sm_buki", Cmd_buki, 0, "tele");
	RegAdminCmd("sm_killmenu", Cmd_killmenu, 0, "tele");
	RegAdminCmd("sm_killspawn", Cmd_killspawn, 0, "tele");
	RegAdminCmd("sm_time", Cmd_time, 0, "time");
	RegAdminCmd("sm_waiting", Cmd_waiting, 0, "loop WaitingForPlayers");
	RegAdminCmd("sm_dragon", Cmd_dragons, 0, "");
	RegAdminCmd("sm_entinput", Cmd_EntInput, 0, "");
	RegAdminCmd("sm_ent", Cmd_Ent, 0, "");
	RegAdminCmd("sm_entspawn", Cmd_EntSpawn, 0, "");
	RegAdminCmd("sm_prop", Cmd_prop, 0, "");
	
	
	
	//cvar
	v_spec = CreateConVar("sm_spec_say", "1", "1 = 観戦者の発言をゲーム中のプレイヤーに送信する");
	v_spawn = CreateConVar("sm_force_respawn", "0", "1 = 常に強制的にスポーンする");
	v_debug = CreateConVar("sm_amg_debug", "0", "1 = 各種でバッグ機能をONにする");
	
	//コマンドを監視
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	//AddCommandListener(Command_Say, "say_team");
	//AddCommandListener(OnPlayerTeamChanged_Listen, "jointeam");
	
	AddCommandListener (Command_All);
	
	//event
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_score_changed", OnPlayerScoreChanged);
	HookEvent("rocketpack_launch", OnPlayerrocketlaunch);
	//HookEvent("teamplay_flag_event", OnFlagPick,EventHookMode_Pre);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	
	HookEntityOutput("item_teamflag", "OnPickUp", eo_FlagPickup);
	
}

public OnPlayerrocketlaunch(Handle:event, const String:name[], bool:dontBroadcast){

	SetEntPropFloat(GetClientOfUserId(GetEventInt(event, "userid")), Prop_Send, "m_flItemChargeMeter", 100.0,1);

}

public EntityHook(const char[] output, int caller, int activator, float delay){
	PrintToChatAll("%d",GetEntProp(caller, Prop_Data, "m_iHealth"));
	PrintToChatAll("%s",output);
	PrintToChatAll("m_iHealth");
}

public Action:Cmd_Ent(client, args){
	new String:ent[250];
	new String:input[250];
	if(args != 2){
		return Plugin_Continue;
	}
	GetCmdArg(1,ent,250);
	GetCmdArg(2,input,250);
	AcceptEntityInput(StringToInt(ent),input);
}

public Action:Cmd_EntSpawn(client, args){
	new String:entname[250];
	new ent = -1;
	if(args != 1){
		return Plugin_Continue;
	}
	GetCmdArg(1,entname,250);
	
	ent = CreateEntityByName(entname);
	
	if(ent != -1){
		PrintToChat(client,"Entityの作成に失敗しました");
	}
	else{
		PrintToChat(client,"Entityを作成しました。EntityIndex:%d",ent);
	}
}

new renban = 0;

//デバッグ用 プラグインのリロード
public Action:Cmd_reload(client, args){
	ServerCommand("sm plugins reload amg_plugins");
	ReplyToCommand(client,"AMGプラグインをリロードしました。");
	PrintToServer("Tick:%d",GetGameTickCount());
	return false;
}

public Action:Cmd_prop(client, args){

	//new ent = CreateEntityByName("prop_dynamic");
	new ent = CreateEntityByName("prop_physics_override");
	
	new filter;
	new flag;
	new String:temp[255];
	

	//フィルター関係///////////////////////////
	
	while ((filter = FindEntityByClassname(filter, "filter_activator_tfteam")) != -1){
		GetEntPropString(filter, Prop_Data, "m_iName", temp,255);
		if(StrEqual(temp,"prop_filter")){
			//既にフィルターが生成されていた場合、削除する
			//PrintToChat(client,"kill filter:%d",filter);
			AcceptEntityInput(filter, "Kill");
		}
	}
	
	filter = CreateEntityByName("filter_activator_tfteam");	//フィルターを作成する
	SetEntProp(filter, Prop_Data, "m_iTeamNum",TFTeam_Blue);	//フィルター対象チームを設定
	
	DispatchSpawn(filter);	//スポーンさせる	
	
	//フィルター名を設定する
	SetEntPropString(filter, Prop_Data, "m_iName", "prop_filter");

	//Propにフィルターを設定する
	//フィルター名とフィルターEntityが両方必要？
	SetEntPropString(ent, Prop_Data, "m_iszDamageFilterName","prop_filter");
	
	//PropにフィルターEntityを設定
	SetEntPropEnt(ent, Prop_Data, "m_hDamageFilter",filter);
	
	//Prop関係//////////////////////////////////////
	
	//Propのダメージイベントをフックする
	HookEntityOutput("prop_physics","OnTakeDamage",EntityHook);
	//HookSingleEntityOutput(ent,"OnHealthChanged",EntityHook);
	
	//PrintToChat(client,"%d",GetEntProp(ent, Prop_Data,"m_OnTakeDamage"));
	
	//Propにモデルを設定する
	SetEntPropString(ent, Prop_Data, "m_ModelName", "models/props_hydro/water_barrel_cluster.mdl");
	//衝突判定を設定
	SetEntProp(ent, Prop_Data, "m_nSolidType",6);
	
	//チェックのために名前をつける 同じ名前は付けられない(破壊されていても)
	Format(temp,255,"prop_test_%d",renban++);
	SetEntPropString(ent, Prop_Data, "m_iName", temp);
	
	//Propをスポーンさせる
	if(DispatchSpawn(ent) == false){
		PrintToChat(client,"spawn faild");
	}
	GetEntPropString(ent, Prop_Data, "m_iName", temp, 255);
	PrintToChat(client,"Prop:%d",ent);
	PrintToChat(client,"entname %s", temp);
	GetEdictClassname(ent,temp,255);
	PrintToChat(client,"entclassname %s", temp);
	
	
	//Propのヘルスを設定する
	SetEntProp(ent, Prop_Data, "m_iHealth", 100);
	
	//Propがダメージを受けるようにする
	SetEntProp(ent, Prop_Data, "m_takedamage", 2, 1);	//Mortal
	
	// GetEntPropString(ent, Prop_Data, "m_iClassname", temp, 255);
	// PrintToChat(client,"m_iClassname %s", temp);
	
	//位置を保存
	new float:vec[3];
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vec);
	PrintToChat(client,"Vec %d,%d,%d",vec[0],vec[1],vec[2]);
	GetClientAbsOrigin(client, vec);
	PrintToChat(client,"Vec %d,%d,%d",vec[0],vec[1],vec[2]);
	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vec);
	PrintToChat(client,"Vec %d,%d,%d",vec[0],vec[1],vec[2]);
	
	// ent = -1;
	// while ((ent = FindEntityByClassname(ent, "prop_physics_override")) != -1){
		// PrintToChat(client,"ent %d",ent);
		// GetEntPropString(ent, Prop_Data, "m_iGlobalname", temp, 255);
		// PrintToChat(client,"entname %s", temp);
	// }
	
	
	
}

//ドラゴン渡しテスト
public Action:Cmd_dragons(client, args){
	TF2Items_GiveWeapon(client,21);
	
	new ent = -1;
	//new Owner;
	while ((ent = FindEntityByClassname(ent, "tf_weapon_flamethrower")) != -1){
		if(client == GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") && GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex") == 21){
			SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", 1178);
			SetEntProp(ent, Prop_Send, "m_iEntityLevel", 5);
			SetEntProp(ent, Prop_Send, "m_iEntityQuality", 6);
			SetEntProp(ent, Prop_Send, "m_bInitialized", 1);
		}
	}
}

public Action:Command_All(client, const String:command[], argc){

	new String:strCmd[200];
	new String:strTemp[200];
	new i;
	for(i=0;i<=argc;i++){
		GetCmdArg(i,strTemp,200);
		Format(strCmd,200,"%s %s",strCmd,strTemp);
	}
	if(GetConVarInt(v_debug)){
		PrintToServer("Client:%d",client);
		PrintToServer("CommandListener:%s",strCmd);
	}
 }
public Action:Cmd_time(client, args){
	new ent = -1;
	ent = FindEntityByClassname(ent, "team_round_timer");
	
	if(ent == -1){
		return false;
	}
	
	FireEntityOutput(ent,"OnSetupFinished");
	
}


new endflag = 0;
public Action:Cmd_waiting(client, args){

	new String:arg[10];
	GetCmdArg(1,arg,10);
	if(StrEqual(arg,"end")){
		endflag = 1;
	}
	else{
		Cmd_WaitTimer();
	}
}
public Cmd_WaitTimer(){
	if(endflag){
		endflag = 0;
	}
	else{
		CreateTimer(20.0,Cmd_restart);
	}
}

public Action:Cmd_restart(Handle:timer){
	ServerCommand("mp_waitingforplayers_restart 1");
	Cmd_WaitTimer();
}


//HookEvent 被ダメ時
public OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_debug) == 0){
		return false;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	/*
	GetEventInt(event, "custom")
	ヘッドショット:1
	バックスタブ:2
	
	スナイパーライフル:11
	しっこ銃:14
	
	*/
	
	PrintToServer("Health:%d",GetClientHealth(client));
	
	if(GetEventInt(event, "health") == 0 && GetEventInt(event, "custom") != 2){
		SetEntityHealth(client,100);
	}
}

public Action:Cmd_killspawn(client, args){
	new iDoor = -1;
	while ((iDoor = FindEntityByClassname(iDoor, "func_respawnroomvisualizer")) != -1)	//名前からエンティティを探す
	{	//func_respawnroomvisualizerスポーン地点の進入禁止を削除
		PrintToServer("attayo");
		AcceptEntityInput(iDoor, "Kill");	//ｲﾗｯとしたから死んでもらう
	}
}

public Action:Cmd_buki(client, args){
	new String:arg[10];
	GetCmdArg(1,arg,sizeof(arg));
	//PrintToServer("buki %s",arg);
	if(args > 0){
		TF2_RemoveAllWeapons(client);
		PrintToServer("[AMGPlugins]GiveWeapon Client:%d wdi:%d",client,StringToInt(arg));
		TF2Items_GiveWeapon(client,StringToInt(arg));
	}
	TF2_AddCondition(client, TFCond_TeleportedGlow, 5.0);
}

public Action:Cmd_EntInput(client, args){

	new String:ent[250];
	new String:input[250];
	if(args != 2){
		return Plugin_Continue;
	}
	GetCmdArg(1,ent,250);
	GetCmdArg(2,input,250);
	PrintToChat(client,"Input %s",input);
	Entity_Input(ent,input);
}

public Action:Cmd_debug(client, args){
	test(client);
	return;
	//new String:args[30];
	//GetCmdArgString(args,30);
	//PrintToServer("%s",args);
	//Entity_Input("item_teamflag",args);
	
	//TF2Attribのテスト
	//new primary = GetPlayerWeaponSlot(client, 0);
	//PrintToServer("primary %d",primary);
	//TF2Attrib_SetByName(primary, "max health additive bonus", -200.0);
	
	//AddCommandOverride("sm_debug", Override_Command, 0)
	
	new String:ArgString[100];
	GetCmdArg(0,ArgString,100);
	PrintToChat(client,"%s",ArgString);
	
	new Handle:Array = CreateArray(4,2);
	new String:buffer[255] = "123456789";

	PrintToServer("%.3s",buffer[1]);
	
	SetArrayCell(Array,0,2147483647);
	SetArrayString(Array,1,"teststring");
	GetArrayString(Array,1,buffer,sizeof(buffer));
	PrintToServer("GetArraySize:%d",GetArraySize(Array));
	PrintToServer("GetArrayCell:%d",GetArrayCell(Array,0));
	PrintToServer("GetArrayCell2:%d",GetArrayCell(Array,1));
	PrintToServer("GetArrayString:%s",buffer);
	SetArrayCell(Array,0,2147483648);
	PrintToServer("GetArrayCell:%d",GetArrayCell(Array,0));
		//使い終わったら閉じる
	CloseHandle(Array);
}


new Handle:m_menu = INVALID_HANDLE;

//menuのテスト
public Action:Cmd_menu(client, args){

	m_menu = CreateMenu(MenuList);
	AddMenuItem(m_menu, "test", "test", ITEMDRAW_DEFAULT);
	DisplayMenu(m_menu,client,MENU_TIME_FOREVER);
	PrintToChat(client,"Frags:%d",GetClientFrags(client));
}
public Action:Cmd_killmenu(client, args){

	if(m_menu != INVALID_HANDLE){
		CloseHandle(m_menu);
		//CancelMenu(m_menu);
		//DisplayMenu(m_menu,client,MENU_TIME_FOREVER);
	}
}
public MenuList(Handle:menu, MenuAction:action, param1, param2) {
	switch(action){	//MenuAction チェック
			case MenuAction_Select:{
				PrintToChatAll("メニューが選択されたよ　hundle:%x",menu);
			}
			//メニュー処理が終了した
			case MenuAction_End:{
				PrintToChatAll("メニューが終了したよ　hundle:%x",menu);
				PrintToChatAll("param1:%d",param1);
				PrintToChatAll("MenuEnd_Cancelled:%d",MenuEnd_Cancelled);
				PrintToChatAll("MenuEnd_Selected:%d",MenuEnd_Selected);
				PrintToChatAll("MenuEnd_Exit:%d",MenuEnd_Exit);
				CloseHandle(menu);	//終了したらハンドルを閉じておく
			}
	}
	
	//戻り値を必要をする状況があるため、エラー回避に0を返す
	return 0;
}


//位置保存とか

new Float:vec[3];
new Float:ang[3];
	
public Action:Cmd_telesave(client, args){

	PrintToChat(client,"save");
	PrintToChat(client,"%d",GetClientFrags(client));
	
	//位置を保存
	GetClientAbsOrigin(client, vec);
	
	//角度を保存
	GetClientEyeAngles(client, ang);
	
	PrintToServer("%f",GetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 0));
	PrintToServer("%f",GetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 1));
	PrintToServer("%f",GetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 2));
	SetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 50.0,1)
	PrintToServer("%d",GetEntPropArraySize(client, Prop_Send, "m_flItemChargeMeter"));

}

public Action:Cmd_teleload(client,args){
	PrintToChat(client,"load");
	TeleportEntity(client, vec, ang, NULL_VECTOR);
}

//HookEvent Score変動時
public OnPlayerScoreChanged(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_debug) == 0){
		return false;
	}

	PrintToServer("client:%d score:%d",GetEventInt(event,"player"),GetEventInt(event,"delta"));
	PrintToServer("GetEntProp:%d",GetEntProp(GetEventInt(event,"player"), Prop_Send, "m_iPoints", 4));
	
}

//HookEvent Flag取得時
public OnFlagPick(Handle:event, const String:name[], bool:dontBroadcast){
	//Entity_Input("item_teamflag","ForceReset");
	return Plugin_Handled;
	}

public eo_FlagPickup(const String:output[], caller, activator, Float:delay) {
	PrintToServer("PickUp");
	return Plugin_Handled;
}
	
public Action:Cmd_health(client, args){
	//test(client);
	new String:Path[30];
	//BuildPath("", Path, sizeof(Path), "mapcycle.txt");
	//PrintToServer("%s",Path);
	//ファイルが存在するかどうか
	if(FileExists("mapcycle.txt") == true){
		PrintToServer("attayo");
	}
}

public test(int client){
	
	if(g_ent != -1){
		RemoveEdict(g_ent);
		SDKUnhook(g_ent, SDKHook_SetTransmit, Hook_SetTransmit);
		g_ent = -1;
	}
	
	PrintToServer("1");
	
	new Float:pos[3];
	GetClientAbsOrigin(client, pos);	//プレイヤーの現在地を取得
	pos[2] += 100.0;	//Z軸に＋して頭上に来るようにする
	
		PrintToServer("2");
	new ent = CreateEntityByName("info_particle_system");	//パーティクルを生成する
	if(SDKHookEx(ent, SDKHook_SetTransmit, Hook_SetTransmit)){
		PrintToServer("SDKHookEx ok");
	}
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);		//パーティクルをclientの位置に設定する
	
	decl String:name[128];
	Format(name, sizeof(name), "effect_%i", ent);	//パーティクルに名前をつける(ent番号でユニーク化する)
	DispatchKeyValue(ent, "targetname", name);
	//DispatchKeyValue(ent, "effect_name", "duel_blue");
	DispatchKeyValue(ent, "effect_name", "unusual_steaming");//呼び出すパーティクルを指定
	DispatchSpawn(ent);		//パーティクル出現
	ActivateEntity(ent);	//?パーティクルのアクティブ化？アニメーションがあるものを動作させる？
	//SetVariantString(name);	//分からない　これどこに送ってるの？
    //SetVariantString("flag");
	AcceptEntityInput(ent, "start");	//パーティクルの実行　アニメーション開始？
	PrintToServer("3");
	Format(name, sizeof(name), "target%i", client);
	DispatchKeyValue(client, "targetname", name);	//パーティクルの親(client)に命名
	DispatchKeyValue(ent, "parentname", name);		//名前から親を指定
	SetVariantString(name);
	AcceptEntityInput(ent, "SetParent");//, ent, ent, 0);
	//SetVariantString(name);
	//AcceptEntityInput(ent, "SetParentAttachment", ent, ent, 0);
		PrintToServer("4");
	
	g_ent = ent;
	
	PrintToChatAll("5");
	//Hook_SetTransmit(ent,client);

}

public Action:Hook_SetTransmit(ent, client) 
{

	PrintToChatAll("hook %d",client);

	if(client == 2){
		PrintToChatAll("can see %d",client);
		return Plugin_Continue;
	}
	PrintToChatAll("can't see %d",client);

	//return Plugin_Handled;
}

public Action:Cmd_debug1(client, args){
	
	new votes[] = {5,3,9,2,4,6,7,1,8,10};
	PrintToServer("sizeof(votes):%d",sizeof(votes));
	new i=0;
	for(i=0;i<10;i++){
		PrintToServer("votes[%d]:%d",i,votes[i]);
	}
	SortIntegers(votes,sizeof(votes),Sort_Descending);
	for(i=0;i<10;i++){
		PrintToServer("votes[%d]:%d",i,votes[i]);
	}
}

//EntityにInputを送信
public Entity_Input(String:classname[], String:Input[]){
	
	int ent = -1;  
 
	while ((ent = FindEntityByClassname(ent, classname)) != -1)  
	{
		PrintToServer("entity %s find",classname);
		int ref = EntIndexToEntRef(ent);
		//PrintToServer("%d",GetEntProp(ref, Prop_Data, "m_nSolidType"));
		//PrintToServer("%d",GetEntProp(ref, Prop_Data, "m_usSolidFlags"));
		PrintToChatAll("ent %d, ref %d",ent,ref);
		AcceptEntityInput(ref, Input);
	}
	
}

//ラウンドを終了させるだけ
public Action:Cmd_win(client, args){
	ServerCommand("mp_forcewin");
}

//ﾁｬｯﾄﾄﾘｶﾞ用
public Action:Command_Say(client, const String:command[], argc){
	//sayコマンドの内容を確保 argcは必ず１（sayコマンドは発言全てを１語として送るようだ）
	
	//ゲーム中のプレイヤーは何もしない
	if(GetClientTeam(client) > 1 || GetConVarInt(v_spec) == 0){
		return false;
	}
	
	new String:strClient[MAX_NAME_LENGTH];
	new String:strSay[192];
	GetCmdArg(1,strSay, sizeof(strSay));
	GetClientName(client,strClient,sizeof(strClient));
	
	PrintToChatAll("\x05%s\x01 :  %s",strClient,strSay);
	PrintToServer("(観戦者)%s :  %s",strClient,strSay);
	
	return Plugin_Handled; // blocks command 本来の発言を消す
}

g_bit = -1;

//HookCmd 
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon){

	if(GetConVarInt(v_debug) == 0){
		return false;
	}

	//Buttonコードをビットで比較する…
	//ビットマスクでIN_ATTACKのビットが立っているかを確認する
	if(g_bit != buttons){
		if(buttons != 0){
			if(client == 1){
				PrintToServer("%d:%d",client,buttons);
				g_bit = buttons;
				//return Plugin_Handled;
			}
			
			
			//PrintToServer("OnPlayerRunCmd bit : %x",buttons);
			//PrintHintText(client, "OnPlayerRunCmd bit : %x",buttons);
		}
	}
		
	if((buttons & IN_ATTACK) == IN_ATTACK){
		SetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 100.0,1);
		//PrintToServer("OnPlayerRunCmd : ATTACK");
	}
	
	//正常処理時でも必要らしい…？ Plugin_Handledでブロックも可能
    //return Plugin_Continue;
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(GetConVarInt(v_spawn) == 0){
		return false;
	}

	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//スポーンさせる
	CreateTimer(0.2, Cmd_EndTimer,client);
}

//ちょっと待ってみる…
public Action:Cmd_EndTimer(Handle:timer, any:client){
	TF2_RespawnPlayer(client);
}

//EventHook チーム変更監視
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){

	// //get player index
	// new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// //PrintToServer("GetClientTeam:%d",GetClientTeam(client));
	// //PrintToServer("GetEventInt(team):%d",GetEventInt(event, "team"));
	// //PrintToServer("GetEventInt(oldteam):%d",GetEventInt(event, "oldteam"));
	// //PrintToServer("GetEventBool(disconnect):%d",GetEventBool(event, "disconnect"));
	
	// if(GetEventInt(event, "oldteam") > 1){
		// PrintToServer("nope!");
		// return Plugin_Handled;
	// }
	
}


	