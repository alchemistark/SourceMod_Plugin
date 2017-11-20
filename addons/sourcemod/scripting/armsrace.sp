#include <sourcemod>
#include <tf2_stocks>
#include <tf2items_giveweapon>

#define SOUND_POINT "Passtime.BallIntercepted"

new g_ar_point[MAXPLAYERS+1];	//取得ポイント
new g_ar_assist[MAXPLAYERS+1];	//アシスト数
new g_ar_winpoint;				//勝利に必要なポイント数
//new g_ar_melee[MAXPLAYERS+1];	//各自所有の近接武器
new Handle:v_enable = INVALID_HANDLE;
new Handle:v_assist = INVALID_HANDLE;
new Handle:v_nodamage = INVALID_HANDLE;
new Handle:v_sound = INVALID_HANDLE;
new Handle:v_cfg = INVALID_HANDLE;
new Handle:v_botkill = INVALID_HANDLE;	//bot殺し用タイマーのonoff
new Handle:t_botkill[MAXPLAYERS+1] = INVALID_HANDLE;	//bot殺し用タイマー
new Handle:v_glow = INVALID_HANDLE;
new Handle:v_glowtime = INVALID_HANDLE;	//glow時間用
new Handle:t_glow[MAXPLAYERS+1] = INVALID_HANDLE;	//glow用タイマー
new Handle:v_spawn = INVALID_HANDLE;	//スポーン方法の選択
new Handle:v_last = INVALID_HANDLE;	//あと1ポイントで勝利する場合メッセージを表示するかどうか


//開始時の変数状態を確保する
new g_mp_forcerespawn;
new g_mp_disable_respawn_times;
//new g_forcewin_flag;

new g_winner;	//別関数に勝利者のIndex番号を持っていきたい
new g_leader_blu //青のスコアトップ
new g_leader_red //赤のスコアトップ

public Plugin:myinfo = 
{
	name = "[TF2]ArmsRace",
	author = "不利ｼﾞｮｲﾅｰAMG",
	description = "軍拡競争",
	version = "1.0",
	url = ""
}

/*
機能追加予定
・言語ファイル追加

確認すべき事
・そもそもアシストで*勝利*できるの？
・やっぱり2ゲーム目で発光が残っているようだが

既知のバグ
・火炎放射器、点火して放置で何故か近接メッセージが出た

仕様
・タウントキルするとシビリアン状態になる(装備を変更すると直る)

最近の修正
・プラグインAdminCheatsに依存する →非依存に
・プラグイン有効時、ラウンドをリスタートする　→した
・無敵解除時、プレイヤーが居なくなっているとエラー　→直した
・ゲーム終了時、社長像キルでメッセージを出さない　→直した
・ポイント獲得時、ヘルスを変更しないようにする（現時点のダメージ値を反映させる、ただし現在のヘルスの値は下回らない）
・ヘルス125クラスからヘルス300クラスになった時ヘルスが減る(125になる)　逆の場合オバヒになる　→直した
・途中参加時、スコアはリセットされるのか？　→恐らく大丈夫　仕込んだメッセージは出た
・武器を全てのスロット変更可能に（伴ってWeapon1～とかをSlot0 Slot1 Slot2に変更する
・プラグインではなくてサーバー側だが、全てのマップでbotが動いているか確認
・消化斧でキルした時ポイントを奪えない
・cfgで装備変更無しのポイント数があった場合、リスポン時に装備が変更されない
・近接ペナルティ受けた人の処理で不要と思われる行を消したため、ペナルティをちゃんと受けているか確認
・ダメージを当ててから近接に持ち替え、その間に敵が自爆した場合近接扱いになる(敵が自爆した時に近接を持っていると近接扱い)
・一部の投擲武器において、発射からキルまでの間に近接に持ち変えると近接キルになる
・近接当ててからリボルバーでトドメで近接キル扱いになった　→再現せず
・↑再現確認　近接当てた後、敵が自爆すると近接キル扱い(武器を持ち替えていても)
・mp_forcewinコマンドからチート属性が外れる
・自殺によるポイントで*勝利*していないか？
・OnPlayerDeathにてクライアント0が発生するので例外処理が必要
・スタックしたbot(指定時間ダメージを受けていないbot)には死んでもらいます。
・キルする(ポイントが入る)と音が鳴るよ
・HUDに現在のスコア(全員分)を表示　名前はチームカラーで色分け
・最初から最後まで同じ装備で行くことができない（ラスト1ポイントのみ装備を変える必要がある、同じ装備にしても再取得してしまう）
・落ちた武器が拾える→武器を落ちなくした
・拾った武器でポイントが入ってしまう（*勝利*できてしまう）→武器を落ちなくした
・配布された武器でしかポイントが入らないように修正する→武器を落ちなくした
・アンロック武器の近接は近接扱いになるか？→ﾕｰﾊﾞｰｿｳで確認 OK
・アシストでポイントを得た時に武器の弾が補充されてしまう（クラス変更処理が行われている）
・アンロック武器の近接は近接扱いになるか？→ﾕｰﾊﾞｰｿｳで確認 OK ←ダメ　全部確認
・ﾛｯｸﾝﾛｰﾄﾞの装弾数がおかしい(武器の仕様が古いまま？)　→恐らくTF2Itemsの問題　→TF2IDB導入で直った
・スパイの武器（24番と61番）が何故かスルーされている →スパイの武器スロットが変更されているため　スロットチェックを外した
・リスポン機能をcvar自動変更か指定秒で強制リスポンかを選択する
・最終スコアの時にメッセージを出す（ヒントメッセージかHUDか選択)
・ラウンドをまたいだ時に発光が消えていない

*/

//プラグイン起動時
public OnPluginStart(){
	
	//cmd
	// RegAdminCmd("sm_reload", Cmd_reload, 0, "デバッグコマンド - プラグインをリロードする");
	
	//cvar
	v_enable = CreateConVar("sm_ar_enable", "0", "軍拡競争モードのOnOffを切り替える");
	v_assist = CreateConVar("sm_ar_assist", "0", "アシストキルでのポイント取得の可否　0で無効、1以上でポイント取得に必要なアシストキルの数");
	v_nodamage = CreateConVar("sm_ar_nodamage", "5", "スポーン直後の無敵時間");
	v_botkill = CreateConVar("sm_ar_botkill", "0", "botのスタック防止用");
	v_sound = CreateConVar("sm_ar_sound", "1", "ポイント取得時にサウンドを鳴らす");
	v_cfg = CreateConVar("sm_ar_cfg", "armsrace.cfg", "設定ファイルを指定する");
	v_glow = CreateConVar("sm_ar_glow", "1", "チームリーダーの発光パターン　0:発光しない 1:両チーム発光 2:スコアトップのみ発光");
	v_glowtime = CreateConVar("sm_ar_glowtime", "3", "チームリーダーの発光時間");
	v_spawn = CreateConVar("sm_ar_spawn", "4", "スポーン方法の選択 0:Cvar ForceSpawnを使用する ANY:強制スポーンさせる。スポーンまでの時間");
	v_last = CreateConVar("sm_ar_last", "2", "後1ポイントで勝利するプレイヤーが出た時、メッセージを表示するか 0:表示しない 1:チャットに表示する 2:ヒントメッセージで表示する");

	//hook
	HookEvent("player_team", OnPlayerTeamChanged);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", OnPlayerSpawned, EventHookMode_Post);
	HookEvent("teamplay_win_panel", OnRoundEnd, EventHookMode_Pre);
	HookEvent("teamplay_round_active", OnRoundStart);
	HookEvent("player_hurt", OnPlayerHurt);
	
	HookConVarChange(v_enable, OnConVarChanged_enable);
	HookConVarChange(v_cfg, OnConVarChanged_cfg);
	HookConVarChange(v_spawn, OnConVarChanged_spawn);
	
}
//デバッグ用 プラグインのリロード
// public Action:Cmd_reload(client, args){
	// ServerCommand("sm plugins reload armsrace");
	// ReplyToCommand(client,"軍拡競争プラグインをリロードしました。");
	// return false;
// }

//マップ終了時にプラグインも終了する
public OnMapEnd(){
	SetConVarInt(v_enable,0,false,false);
}
public OnPluginEnd(){
	SetConVarInt(v_enable,0,false,false);
}

//ConVar変更時（cfgファイル変更時）
public OnConVarChanged_cfg(ConVar convar, const char[] oldValue, const char[] newValue){

	//変更がない(同じものを入れた)場合は実行されない

	//new String:strCfg[PLATFORM_MAX_PATH];
	//Format(strCfg, sizeof(strCfg),"%s",newValue);
	
	//cfgファイルのチェック
	int iFlag[5];
	iFlag[0] = -1;
	if(Cmd_CheckCfg(iFlag) == false){
		SetConVarString(v_cfg,oldValue);
		return Plugin_Handled;
	}
	
	PrintToServer("[ArmsRace]%sを読み込みました。",newValue);
	
	//ゲーム中ならばリスタートする
	if(GetConVarInt(v_enable) == 1){
		ServerCommand("mp_restartgame 3");
	}
	
}

//ConVar変更時（スポーン方法変更時）
public OnConVarChanged_spawn(ConVar convar, const char[] oldValue, const char[] newValue){

	//ゲーム中に変更されると問題が発生するため
	if(GetConVarInt(v_enable) == 0){
		return Plugin_Continue;
	}
	
	//前提：CVarが設定された時に以前と同じ値の場合関数は呼び出されない
	
	//スポーン関連Cvar変更 に設定
	if(StrEqual(newValue,"0")){	//StringToIntのエラー値は0
		//現在のConVar値を保存しておく(リスポン関係)
		g_mp_forcerespawn = GetConVarInt(FindConVar("mp_forcerespawn"));
		g_mp_disable_respawn_times = GetConVarInt(FindConVar("mp_disable_respawn_times"));

		//リスポン時間off
		ServerCommand("mp_forcerespawn 0");
		ServerCommand("mp_disable_respawn_times 1");
	}
	//強制スポーンに設定
	else if(StringToInt(newValue) > 0){
		//リスポン関連ConVarを元に戻す
		ServerCommand("mp_forcerespawn %d", g_mp_forcerespawn);
		ServerCommand("mp_disable_respawn_times %d", g_mp_disable_respawn_times);
	}
}

//ConVar変更時（プラグイン有効無効切り替え時）
public OnConVarChanged_enable(ConVar convar, const char[] oldValue, const char[] newValue){

	if(StringToInt(newValue) == 0){
		//プラグイン終了
		
		//スポーンのためCvarを変更していた場合
		if(GetConVarInt(v_spawn) == 0){
			//リスポン関連ConVarを元に戻す
			ServerCommand("mp_forcerespawn %d", g_mp_forcerespawn);
			ServerCommand("mp_disable_respawn_times %d", g_mp_disable_respawn_times);
		}

		//Entityを動作させる
		
		//サプライロッカーの有効
		Entity_Input("func_regenerate","Enable");
		
		//cpはなんかいっぱい要る
		Entity_Input("team_control_point_master","Enable");
		Entity_Input("team_control_point","Enable");
		Entity_Input("trigger_capture_area","Enable");
		Entity_Input("item_teamflag","Enable");
		Entity_Input("func_capturezone","Enable");
		
		//HUD表示をクリア
		new i,j;
		for(i=1;i<=MaxClients;i++){
			if(IsClientInGame(i) == true){
				for(j=0;j<6;j++){
					SetHudTextParams(0.01, 0.01, 0.01, 255,255,255,255);
					ShowHudText(i, j, "");
				}
			}
		}
		
		return false;
	}
	else if(StringToInt(newValue) != 1){
		PrintToServer("[ArmsRace]ERROR:ConVarの値がおかしいです");
		SetConVarInt(convar,0,false,false);
		return false;
	}
	
	//プラグイン有効化処理
	
	//cfgファイルのチェック
	int iFlag[5];
	iFlag[0] = -1;
	if(Cmd_CheckCfg(iFlag) == false){
		return false;
	}
	
	//スポーンのためCvar変更する場合
	if(GetConVarInt(v_spawn) == 0){
		//現在のConVar値を保存しておく(リスポン関係)
		g_mp_forcerespawn = GetConVarInt(FindConVar("mp_forcerespawn"));
		g_mp_disable_respawn_times = GetConVarInt(FindConVar("mp_disable_respawn_times"));

		//リスポン時間off
		ServerCommand("mp_forcerespawn 0");
		ServerCommand("mp_disable_respawn_times 1");
	}
	
	//リスタートする
	PrintToChatAll("[ArmsRace] Plugin enable. Game restart.");
	ServerCommand("mp_restartgame 3");

}

//cfgファイルのチェック
public bool:Cmd_CheckCfg(int[] iFlag){

	//iFlag[] チェックフラグ 要素数は5以上であること
	//iFlag[0] : チェックするスコア、-1の場合はcfgファイルのチェックのみ　最終的には変更に使用したスコアを格納
	//iFlag[1] : 変更後クラスを格納
	//iFlag[2],[3],[4] : 変更後武器スロット0,1,2を格納
	//！配列サイズは決め打ちなので注意！ 配列サイズの確認方法が分からなかったため

	//configファイルがあるか確認
	//コンフィグファイルのパスを取得
	//Path_SM：SourceModルートフォルダ
	new String:strConfigFile[PLATFORM_MAX_PATH];
	new String:strCfg[PLATFORM_MAX_PATH];
	GetConVarString(v_cfg,strCfg,sizeof(strCfg));
	BuildPath(Path_SM, strConfigFile, sizeof(strConfigFile), "configs/%s",strCfg);
	
		//ファイルが存在するかどうか
	if (FileExists(strConfigFile) == false){
		PrintToServer("[ArmsRace]ERROR:cfgファイルがありません");
		return false;
	}

	//ハンドル作成　ルートはarmsrace
	new Handle:hKeyValues = CreateKeyValues("armsrace");

	//ファイルを読み込む
	if(FileToKeyValues(hKeyValues,strConfigFile) == false || KvGotoFirstSubKey(hKeyValues,false) == false)
	{
	//ファイルを開くのに失敗した（中身がKeyValueでない、サブキーがない）
		PrintToServer("[ArmsRace]ERROR:cfgファイルの読み込みに失敗しました。[%s]",strConfigFile);
		CloseHandle(hKeyValues);
		return false;
	}
	
	new String:point[5];
	
	//ファイルの存在を確認したので、勝利に必要なポイント数を更新し、終了
	if(iFlag[0] == -1){
		//勝利ポイントを確認する(サブキー名(スコア数)が一番大きい値＋１)
		g_ar_winpoint = 0;
		//new String:point[5];
		
		do{
			KvGetSectionName(hKeyValues,point,sizeof(point));
			if(g_ar_winpoint < StringToInt(point)){
				g_ar_winpoint = StringToInt(point);
			}
		}while (KvGotoNextKey(hKeyValues) == true);	//サブキーがある限り実行する
		
		g_ar_winpoint++;
		CloseHandle(hKeyValues);
		return true;
	}
	
	//クラス変更処理読み出し
	
	//このスコアで装備の変更があるか？
	KvGoBack(hKeyValues);	//探索位置を戻す
	IntToString(iFlag[0],point,sizeof(point));
	if(KvJumpToKey(hKeyValues,point,false) == false){
		//今のスコアでは装備の変更は無い(前のスコアの装備を反映させる)
		new i;
		for(i = iFlag[0];i>=0;i--){
			IntToString(i,point,sizeof(point));
			if(KvJumpToKey(hKeyValues,point,false) == true){
				//見つかった
				iFlag[0] = i;
				break;
			}
		}
		//この時点で見つかったスコアの値か0になっているはず
		//なってなければcfgがおかしい
		if(i < 0){
			CloseHandle(hKeyValues);
			PrintToServer("[ArmsRace]ERROR:cfgがおかしいです[%d]",i);
			return false;
		}
	}
	KvGetSectionName(hKeyValues,point,sizeof(point));

	new String:classname[5];
	new String:strWeapon0[5];
	new String:strWeapon1[5];
	new String:strWeapon2[5];
	
	KvGetString(hKeyValues, "classname", classname, sizeof(classname));
	KvGetString(hKeyValues, "Slot0", strWeapon0, sizeof(strWeapon0));
	KvGetString(hKeyValues, "Slot1", strWeapon1, sizeof(strWeapon1));
	KvGetString(hKeyValues, "Slot2", strWeapon2, sizeof(strWeapon2));
	
	//終了したらハンドルを閉じる
	CloseHandle(hKeyValues);
	
	//空欄の武器があった場合数値変換で0になるが、0はバットであるため空欄の場合-1に置換
	iFlag[1] = StringToInt(classname);	//クラスは0で良い
	if(StrEqual(strWeapon0,"")){
		iFlag[2] = -1;
	}
	else{
		iFlag[2] = StringToInt(strWeapon0);
	}
	if(StrEqual(strWeapon1,"")){
		iFlag[3] = -1;
	}
	else{
		iFlag[3] = StringToInt(strWeapon1);
	}
	if(StrEqual(strWeapon2,"")){
		iFlag[4] = -1;
	}
	else{
		iFlag[4] = StringToInt(strWeapon2);
	}
	
	return true;
	
}

//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	//初期化処理
	ArmsRaceStart();
}

//初期化処理
public ArmsRaceStart(){

	new i;
	for(i = 1; i <= MaxClients; i++){
		g_ar_point[i] = 0;
		g_ar_assist[i] = 0;
		
		if(IsClientInGame(i) == true){
			Cmd_ChangeClass(i);
			//Cmd_text(i);
			//何故かHUD表示がされないのでタイマーを仕掛ける
			CreateTimer(0.1, Cmd_EnableHud,i);
			
			//各種タイマーの初期化
			if(t_glow[i] != null){
				KillTimer(t_glow[i]);
				//発行中なら消しておく
				if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
					TF2_RemoveCondition(i, TFCond_TeleportedGlow);
					SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
				}
			}
			if(t_botkill[i] != null){
				KillTimer(t_botkill[i]);
			}
		}
		
		t_glow[i] = null;
		t_botkill[i] = null;
	}
	
	//発光関係
	g_leader_blu = 0;
	g_leader_red = 0;
	
	
	//Entityを止める
	//サプライロッカー停止
	Entity_Input("func_regenerate","Disable");
	
	//CP停止
	Entity_Input("team_control_point_master","Disable");
	Entity_Input("team_control_point","Disable");
	Entity_Input("trigger_capture_area","Disable");
	Entity_Input("item_teamflag","Disable");
	Entity_Input("func_capturezone","Disable");
	
	//勝利者を初期化
	g_winner = 0;
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

//盾を外す
public Cmd_RemoveWear(client,String:classname[]){

	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, classname)) != -1){
		
		//m_iItemDefinitionIndexはアイテムindex、m_hOwnerEntityはクライアント番号で間違いない
		//m_bDisguiseWearableは多分変装したスパイが着用しているかどうかのチェック（軍拡だと気にしなくてOK）
		
		int ItemIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
		int Owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		
		if(Owner == client){
			switch (ItemIndex)
			{
				//ソル靴 133,444
				//デモ靴 405,608
				//砂盾 57,231,642
				//デモ盾 131,406,1099,1144
				case 133,444,405,608,57,231,642,131,406,1099,1144:
				{
					AcceptEntityInput(ent, "Kill");
				}
			}
		}
	}
}

//スポーン時
public OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return false;
	}

	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new time = GetConVarFloat(v_nodamage);
		
	//スポーン後、設定された時間は無敵
	SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);	//Buddha
	CreateTimer(time, Cmd_EndTimer,client);
	
	//botは別に死亡タイマーを仕掛ける
	//死亡時に移動する
	// if(t_botkill[client] != null){
		// KillTimer(t_botkill[client]);
		// t_botkill[client] = null;
	// }
	
	Cmd_ChangeClass(client);
	Cmd_Botkill(client);
	
	//クラスを変更すると最大ヘルスの値が前のクラスのままになる為、数値を決め打ちする
	//new maxHealth[10] = {0, 125, 125, 200, 175, 150, 300, 175, 125, 125};
	//SetEntityHealth(client,maxHealth[GetEntProp(client, Prop_Send, "m_iClass")]);
	
	//何故かHUD表示がされないのでタイマーを仕掛ける
	CreateTimer(0.1, Cmd_EnableHud,client);
}

//スポーン後HUD表示
public Action:Cmd_EnableHud(Handle:timer, any:client){
	Cmd_text(client);
}

//スポーン後無敵解除
public Action:Cmd_EndTimer(Handle:timer, any:client){
	if(client != 0 && IsClientInGame(client) == true && IsPlayerAlive(client) == true){
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);	//Mortal
	}
}

//一定時間戦闘していないbotを殺すタイマー
public Cmd_Botkill(int client){
	//bot判定式　（サーバーでない、ゲーム中である、botである）
	if(client != 0 && IsClientInGame(client) == true && IsFakeClient(client) == true 
		&& GetConVarInt(v_botkill) > 0){	//cvarが有効(1秒以上である
		//既にタイマーが起動しているならタイマーを削除する
		if(t_botkill[client] != null){
			KillTimer(t_botkill[client]);
		}
		t_botkill[client] = CreateTimer(GetConVarFloat(v_botkill), Cmd_KillBot_timer,client);
	}
}

//スタックしたbotを始末する
public Action:Cmd_KillBot_timer(Handle:timer, any:client){
	if(client != 0 && IsClientInGame(client) == true && IsFakeClient(client) == true 
		&& GetConVarInt(v_botkill) > 0){	//cvarが有効(1秒以上である
		ForcePlayerSuicide(client);
	}
	t_botkill[client] = null;	//タイマーは終了しているため、開放する
}

//クラス変更処理
public Cmd_ChangeClass(int client){

	//cfgファイルのチェック
	int iFlag[5];
	iFlag[0] = g_ar_point[client];
	if(Cmd_CheckCfg(iFlag) == false){
		return false;
	}
	
	//以後、iFlag[1]~[4]はクラスと武器が格納されているはず
	
	//cfgチェック
	if(iFlag[1] < 1 || iFlag[1] > 9){
		//クラスが0の場合、前のクラス変更を探しに行く(1度変更したクラスだから信用する)
		if(iFlag[1] == 0){
			do{
				iFlag[0]--;
				if(iFlag[0] < 0){
					PrintToServer("[ArmsRace]ERROR: cfgのクラス指定が不正です(恐らく最初のクラスが0です)");
					return false;
				}
				Cmd_CheckCfg(iFlag);
			}while(iFlag[1] == 0);	//前のセクションもクラスが0
		}
		else{
			PrintToServer("[ArmsRace]ERROR: cfgのクラス指定が不正です(0～9以外の値を検出)");
			return false;
		}
	}
	//クラス変更時、変更前に受けていたダメージを反映させる　ただし、変更前のヘルスは下回らない
	//ex.ヘビー(120/300)がスカウトに変わった場合、ヘルスが180減ると死ぬので120に設定する
	int iHealth[4];	//前のクラスのヘルス最大値と後のクラスのヘルス最大値
	int iDamage;
	
	//現在のヘルス
	iHealth[0] = GetClientHealth(client);
	
	//今のクラスのヘルス最大値
	//クラスを変更すると最大ヘルスの値が前のクラスのままになる為、数値を決め打ちする
	new maxHealth[10] = {0, 125, 125, 200, 175, 150, 300, 175, 125, 125};
	
	//現在のクラスのヘルス最大値を保存
	iHealth[1] = maxHealth[GetEntProp(client, Prop_Send, "m_iClass")];
	
	//クラスを変更
	TF2_SetPlayerClass(client, iFlag[1]);
	
	//後のクラスのヘルス最大値を保存
	iHealth[2] = maxHealth[GetEntProp(client, Prop_Send, "m_iClass")];
	
	iDamage = iHealth[1] - iHealth[0];	//ダメージ値を確保
	iHealth[3] = iHealth[2] - iDamage;	//ダメージ値を反映
	
	//一旦武器をすべて外す
	TF2_RemoveAllWeapons(client);
	
	//ダメージ反映後、元のヘルスを下回るなら
	if(iHealth[3] < iHealth[0]){
		//最大HPが下がっていた場合、オバヒになるため
		if(iHealth[0] > iHealth[2]){
			SetEntityHealth(client,iHealth[2]);
		}else{
			SetEntityHealth(client,iHealth[0]);
		}
	}
	//オバヒしていたら
	else if(iHealth[3] > iHealth[2]){
		SetEntityHealth(client,iHealth[2]);
	}
	else{
		SetEntityHealth(client,iHealth[3]);
	}
	
	//装飾装備を外す
	Cmd_RemoveWear(client,"tf_wearable");
	Cmd_RemoveWear(client,"tf_wearable_demoshield");
	
	//スコアに応じた装備に変更
	//空欄でない、武器が存在する
	new i;
	for(i=2;i<5;i++){
		if(iFlag[i] >= 0 && TF2Items_CheckWeapon(iFlag[i]) == true){
			//スロットの位置が正しい
			//if(TF2Items_CheckWeaponSlot(iFlag[i]) == i-2){	//汚いコード
				//スロットの位置を確認しない
				TF2Items_GiveWeapon(client,iFlag[i]);
			//}
		}
	}
		
}

//HookEvent 被ダメ時(botスタック防止)
public OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast){

	//プラグインが有効なら実行
	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	
	//死ぬ直前に武器を外しておく　武器拾い防止
	if(GetEventInt(event, "health") == 0){
		TF2_RemoveAllWeapons(GetClientOfUserId(GetEventInt(event, "userid")));
	}

	//CVarが有効なら実行
	if(GetConVarInt(v_botkill) <= 0 ){
		return false;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	//botがダメージを受けたらタイマーをリセットする
	if(t_botkill[client] != null && IsClientInGame(client) == true && IsFakeClient(client) == true){
		// KillTimer(t_botkill[client]);
		// t_botkill[client] = null;
		//タイマー再始動
		Cmd_Botkill(client);
	}
	//botがダメージを与えてもタイマーをリセットする
	if(t_botkill[attacker] != null && IsClientInGame(attacker) == true && IsFakeClient(attacker) == true){
		// KillTimer(t_botkill[attacker]);
		// t_botkill[attacker] = null;
		//タイマー再始動
		Cmd_Botkill(attacker);
	}

}

//HookEvent チーム変更監視
public OnPlayerTeamChanged(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	
	//get player index
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//チームが変更された場合、スコアをリセットする
	g_ar_point[client] = 0;
	g_ar_assist[client] = 0;

	//発光タイマーを解除する
	if(t_glow[client] != null){
		KillTimer(t_glow[client]);
		t_glow[client] = null;
		TF2_RemoveCondition(client, TFCond_TeleportedGlow);
	}
	
	//HUD更新
	Cmd_text(0);
	
	//リーダーを取得する
	Cmd_leader();
}

//HookEvent 死亡時
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast){

	//プラグイン有効時のみ
	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	
	//デッドリンガーは除外する
	if(GetEventInt(event,"death_flags") & TF_DEATHFLAG_DEADRINGER == TF_DEATHFLAG_DEADRINGER){
		return false;
	}
	
	//キルした人
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	new String:attacker_Name[MAX_NAME_LENGTH];
	GetClientName(attacker,attacker_Name,sizeof(attacker_Name));
	
	//死んだ人
	new die_client = GetClientOfUserId(GetEventInt(event,"userid"));
	new String:die_client_Name[MAX_NAME_LENGTH];
	GetClientName(die_client,die_client_Name,sizeof(die_client_Name));
	
	//アシストした人
	new assister = GetClientOfUserId(GetEventInt(event,"assister"));
	
	//スポーン方法が強制スポーンの場合、設定時間後スポーンさせるタイマーを作動させる
	//動作はゲーム中に限る(勝利者が空である)
	if(GetConVarInt(v_spawn) > 0 && g_winner == 0){
		//BOTを除く
		if(IsFakeClient(die_client) == false){
			CreateTimer(GetConVarFloat(v_spawn), Cmd_Respawn, die_client);
		}
		else{
			//BOTは即スポーンする
			//TF2_RespawnPlayer(die_client);
			CreateTimer(0.2, Cmd_Respawn, die_client);
		}
	}
	
	//完全落下死だとｱﾀｯｶｰ0、ｱｼｽﾀｰ-1
	
	if(die_client == attacker || GetEventInt(event,"attacker") == 0){
		//本当にただの自殺はカウントしない
		return false;
	}
	
	//2回使用する為先に宣言しておく cfgチェック用
	int iFlag[5];
	
	//キルを取った人にポイントを加算
	g_ar_point[attacker]++;
	//最終ポイントに到達していたらメッセージを表示する
	if(g_ar_point[attacker] == g_ar_winpoint - 1){
		Cmd_LastMessage(attacker);
	}
	//キルしたら音が鳴る
	if(GetConVarInt(v_sound) == 1){
		ClientCommand(attacker,"playgamesound %s",SOUND_POINT);
	}

	//複数アシストした人にもポイントを加算(assisterには-1がある）	//機能が有効である、アシストしたクライアントが存在する、アシストしたクライアントのポイントが勝利ポイント-1より低い（加算されても勝利ポイントに届かない）
	if(
	GetConVarInt(v_assist) != 0 && assister > 0 && g_ar_point[assister] < (g_ar_winpoint - 1)){
		//アシストポイントを加算
		g_ar_assist[assister]++;
		//規定数アシストしたならば
		if(g_ar_assist[assister] >= GetConVarInt(v_assist)){
			//キルポイントを加算
			g_ar_point[assister]++;
			//最終ポイントに到達していたらメッセージを表示する
			if(g_ar_point[assister] == g_ar_winpoint - 1){
				Cmd_LastMessage(assister);
			}
			//アシストしたプレイヤーゲーム中である、生存している
			if(IsClientInGame(assister) == true && IsPlayerAlive(assister) == true){
				if(GetConVarInt(v_sound) == 1){
					ClientCommand(assister,"playgamesound %s",SOUND_POINT);
				}
				//cfgチェック
				iFlag[0] = g_ar_point[assister];
				if(Cmd_CheckCfg(iFlag) == false){
					return false;
				}
				//このスコアで装備の変更がある、クラスに0が指定されていない、
				if(iFlag[0] == g_ar_point[assister] && iFlag[1] != 0 && assister != 0){
					//クラス変更処理を実施
					Cmd_ChangeClass(assister);
				}
			}
			//アシストポイントを初期化
			g_ar_assist[assister] = 0;
		}
	}
	
	//キルに使用された武器が近接ならばキルされた人のポイント減	
	new eCkill = GetEventInt(event, "customkill");
	new eWeaponID = GetEventInt(event, "weaponid");
	
	//トドメが近接、かつ直接の死亡理由が自殺でない
	//if(eCkill != 6 && eWeaponID >= 1 && eWeaponID <= 11){
	if(eCkill != 6 && CheckMelee(eWeaponID)){
		if(g_ar_point[die_client] != 0 && g_ar_point[attacker] < g_ar_winpoint){
			//*勝利者*がポイント奪ったりすると見た目的にアレなので
			g_ar_point[die_client]--;
			//Cmd_ChangeClass(die_client);	//スポーン時にクラスは変更されるので不要
			PrintToChatAll("%sが%sを近接キルし、ポイントを奪った！",attacker_Name,die_client_Name);
		}
	}
	
	if(g_ar_point[attacker] >= g_ar_winpoint && eCkill != 6){
		//勝利ポイントを確保したならばゲームを終了する(ただし自殺を除く)
		g_winner = attacker;
		
		//現在のフラグを保存する
		new forcewin_flag = GetCommandFlags("mp_forcewin");
		//強制的にフラグを落とす(ビットを反転させる→フラグを上げる(反転してるから下がる)→ビットを反転させる)
		new tempFlag = ~GetCommandFlags("mp_forcewin")|FCVAR_CHEAT;
		SetCommandFlags("mp_forcewin",~tempFlag);
		
		//ラウンドを強制的に終了させる
		ServerCommand("mp_forcewin %d",GetClientTeam(attacker));
		//直後に権限を戻そうとすると実行されないのでタイマーで遅延させる
		CreateTimer(1, Cmd_EndCommanFlag,forcewin_flag);
	}
	else{
		//次のクラスへ
		//cfgファイルのチェック
		//int iFlag[5];
		iFlag[0] = g_ar_point[attacker];
		if(Cmd_CheckCfg(iFlag) == false){
			return false;
		}
		//このスコアで装備の変更がある、クラスに0が指定されていない、キルしたプレイヤーが存在する、ゲーム中である、生存している
		if(iFlag[0] == g_ar_point[attacker] && iFlag[1] != 0 && attacker != 0 && IsClientInGame(attacker) == true && IsPlayerAlive(attacker) == true){
			Cmd_ChangeClass(attacker);
		}
		//アシストポイントはリセットされる
		g_ar_assist[attacker] = 0;
	}
	
	/*画面表示を更新する(全員)
	new i;
	for(i=1;i<=MaxClients;i++){
		if(IsClientInGame(i) == true && IsPlayerAlive(i) == true){
		Cmd_text(i);
		}
	}
	*/
	//画面表示を更新する(全員)
	Cmd_text(0);
	
	//リーダーを取得する
	Cmd_leader();
	
	//botの死亡タイマーを解除する
	if(t_botkill[die_client] != null){
		KillTimer(t_botkill[die_client]);
		t_botkill[die_client] = null;
	}
	
	//発光タイマーを解除する
	if(t_glow[die_client] != null){
		KillTimer(t_glow[die_client]);
		t_glow[die_client] = null;
	}
}

//スポーンタイマー
public Action:Cmd_Respawn(Handle:timer, any:client){
	//時間経過後、スポーンする
	if(IsClientInGame(client) == true){
		TF2_RespawnPlayer(client);
	}
}

//最後の武器に到達した時にメッセージを表示する
public Cmd_LastMessage(int client){

	new iLast = GetConVarInt(v_last);
	//機能が有効か？
	if(iLast == 0){
		return Plugin_Continue;
	}

	new String:client_name[MAX_NAME_LENGTH];
	GetClientName(client, client_name, sizeof(client_name));

	new i;
	for(i=1;i<MaxClients;i++){
		if(IsClientInGame(i) == true && IsFakeClient(i) == false){
			switch(iLast){
				case 1:
				{
					PrintToChat(i, "%sが最後の武器に到達しました！",client_name);
				}
				case 2:
				{
					PrintHintText(i, "%sが最後の武器に到達しました！",client_name);
				}
			}
		}
	}
}

//近接武器かどうかの確認
public CheckMelee(int weaponid){
	
	switch(weaponid){
		case	TF_WEAPON_BAT,
				TF_WEAPON_BAT_WOOD,
				TF_WEAPON_BOTTLE,
				TF_WEAPON_FIREAXE,
				TF_WEAPON_CLUB,
				TF_WEAPON_CROWBAR,
				TF_WEAPON_KNIFE,
				TF_WEAPON_FISTS,
				TF_WEAPON_SHOVEL,
				TF_WEAPON_WRENCH,
				TF_WEAPON_BONESAW,
				TF_WEAPON_SWORD,
				TF_WEAPON_STICKBOMB,
				TF_WEAPON_BAT_FISH,
				TF_WEAPON_BAT_GIFTWRAP:
		{
			return true;
		}
	}
	
	return false;
}

//コマンド実行権限を元に戻す
public Action:Cmd_EndCommanFlag(Handle:timer, any:flag){
	SetCommandFlags("mp_forcewin",flag);
}

//チームリーダーを確認する
public Cmd_leader(){

	new i;
	//スコアトップ者を探す
	for(i=1;i<=MaxClients;i++){
		if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Blue){
			if(g_ar_point[g_leader_blu] < g_ar_point[i]){
				g_leader_blu = i;
			}
		}
		else if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Red){
			if(g_ar_point[g_leader_red] < g_ar_point[i]){
				g_leader_red = i;
			}
		}
	}
	
	//トップ1人のみ光る場合
	if(GetConVarInt(v_glow) == 2){
		if(g_ar_point[g_leader_blu] == g_ar_point[g_leader_red]){
			//トップ2名が同点なので光らない
			g_leader_blu = 0;
			g_leader_red = 0;
		}
		else if(g_ar_point[g_leader_blu] < g_ar_point[g_leader_red]){
			//赤のリーダーのみ光る
			g_leader_blu = 0;
		}
		else if(g_ar_point[g_leader_blu] > g_ar_point[g_leader_red]){
			//青のリーダーのみ光る
			g_leader_red = 0;
		}
	}
	
	//スコアトップが複数名居ないか確認する
	//存在した場合リーダー無し
	for(i=1;i<=MaxClients;i++){
		if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Blue){
			if(g_ar_point[g_leader_blu] == g_ar_point[i] && i != g_leader_blu){
				g_leader_blu = 0;
			}
		}
		else if(IsClientInGame(i) == true && GetClientTeam(i) == TFTeam_Red){
			if(g_ar_point[g_leader_red] == g_ar_point[i] && i != g_leader_red){
				g_leader_red = 0;
			}
		}
	}
	
	//新リーダー以外が発光してたら発光を消す
	for(i=1;i<=MaxClients;i++){
		//発光している
		if(t_glow[i] != null){
			//それはリーダーか？
			if(i != g_leader_blu && i != g_leader_red){
				//タイマーを消して発光を消す
				KillTimer(t_glow[i]);
				t_glow[i] = null;
				TF2_RemoveCondition(i, TFCond_TeleportedGlow);
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
			}
		}
	}
}

//HookCmd 
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon){

	//クライアントが不正、プラグインが無効、発光が無効、発光時間が０以下
	if(client == 0 || GetConVarInt(v_enable) == 0 || GetConVarInt(v_glow) == 0 || GetConVarFloat(v_glowtime) < 0){
		return false;
	}

	//どちらかのチームのリーダーである（同点が居る場合リーダーは0にされるので問題ない）
	if(client == g_leader_blu || client == g_leader_red){
		//Buttonコードをビットで比較する…
		//ビットマスクでIN_ATTACKのビットが立っているかを確認する スコアが0のリーダーは光らない
		if((buttons & IN_ATTACK) == IN_ATTACK && g_ar_point[client] > 0){
			//発光する
			//TF2_AddCondition(client, TFCond_TeleportedGlow, GetConVarFloat(v_glowtime));
			TF2_AddCondition(client, TFCond_TeleportedGlow);
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
			//発光終了タイマー
			if(t_glow[client] != null){
				KillTimer(t_glow[client]);
			}
			else{
				//タイマーが存在しない場合だけ表示ね　うるさいから
				PrintHintText(client, "YOU ARE TEAM LEADER!!");
			}
			t_glow[client] = CreateTimer(GetConVarFloat(v_glowtime), Cmd_EndGlow,client);
		}
	}
	//正常処理時でも必要らしい…？→なくてもいい Plugin_Handledでブロックも可能
    //return Plugin_Continue;
}

//発光終了タイマー
public Action:Cmd_EndGlow(Handle:timer, any:client){

	if(IsClientInGame(client) == true && IsPlayerAlive(client) == true){
		TF2_RemoveCondition(client, TFCond_TeleportedGlow);
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
	}
	t_glow[client] = null;
}

//画面表示を更新する(0:全クライアント any:指定クライアント)
public Cmd_text(int client){

	//現時点のランキングを作成する
	new iRank[6];
	new l_ar_point[MAXPLAYERS+1];
	
	new i,j,temp;
	//スコアコピー
	for(i=1;i<=MaxClients;i++){
		l_ar_point[i] = g_ar_point[i];
	}
	
	for(i=0;i<6;i++){
		temp = -1;	//初期化(スコア0がある)
		for(j=1;j<=MaxClients;j++){
			//一番スコアの高いクライアントを保存(観戦を除く）
			if(temp < l_ar_point[j] && IsClientInGame(j) == true){
				temp = l_ar_point[j];
				iRank[i] = j;
			}
		}
		l_ar_point[iRank[i]] = -1;	//既にランキング入りしているので削除
	}
	
	new RED,BLU;
	new String:strName[MAX_NAME_LENGTH];
	
	//HUDに表示する
	for(i=0;i<6;i++){
		if(iRank[i] != 0 && IsClientInGame(iRank[i]) == true){
			if(GetClientTeam(iRank[i]) == 2){
				RED = 255;
				BLU = 0;
			}
			else if(GetClientTeam(iRank[i]) == 3){
				RED = 0;
				BLU = 255;
			}
			/*
			else{
				//無いとは思うが観戦者のスコア０を拾った場合
				RED = 0;
				BLU = 0;
			}
			*/
			
			GetClientName(iRank[i],strName,sizeof(strName));
			
			SetHudTextParams(0.01, 0.08 + (0.03 * i), 300.0, RED,0,BLU,255);
			//ShowHudText(client, i, "%s:%d",strName,g_ar_point[iRank[i]]);
			//ShowHudText(client, i, "%d:%s",g_ar_point[iRank[i]],strName);

			if(client == 0){
				//画面表示を更新する(全員)
				//new j;
				for(j=1;j<=MaxClients;j++){
					if(IsClientInGame(j) == true && IsPlayerAlive(j) == true){
						ShowHudText(j, i, "%d:%s",g_ar_point[iRank[i]],strName);
					}
				}
			}
			else{
				//画面表示を更新する(指定クライアントのみ)
				if(IsClientInGame(client) == true && IsPlayerAlive(client) == true){
					ShowHudText(client, i, "%d:%s",g_ar_point[iRank[i]],strName);
				}
			}
		}
	}
}

//HookEvent ラウンド終了時
public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(GetConVarInt(v_enable) == 0){
		return false;
	}
	
	new String:strWinner[3];
	
	Format(strWinner,3,"%c",g_winner);
	
	//勝利HUDを書き換える cappersはIndex番号を16進にして並べたもの
	SetEventString(event,"cappers",strWinner);
	//g_winner = 0;
}