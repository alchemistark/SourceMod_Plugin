#include <sourcemod>
#include <sdktools>

new Handle:v_enable = INVALID_HANDLE;

public Plugin:myinfo =
{
	//プラグイン情報を記述
	name = "[TF2]PropDemolition",
	author = "AMG",
	description = "全部破壊したら勝ち",
	version = "",
	url = ""
}

//プラグイン起動時
public OnPluginStart(){

	//Cvar
	v_enable = CreateConVar("sm_pd_enable", "0", "モードのオンオフ");
	
	//cmd
	RegAdminCmd("sm_pd_test", Cmd_test, 0, "");
	
	//HookEvent
	HookEvent("teamplay_round_active", OnRoundStart);
	
}

//機能テスト
public Action:Cmd_test(client, args){

	new ent = CreateEntityByName("team_round_timer");
	if(ent == -1){
		PrintToChat(client,"ent error");
	}
	//スポーンさせる
	DispatchSpawn(ent);
	
	PrintToChat(client,"%d,%d,%d,%d",GetEntProp(ent, Prop_Data, "m_bIsDisabled"), GetEntProp(ent, Prop_Data, "m_bStartPaused"), GetEntProp(ent, Prop_Data, "m_nTimerInitialLength"), GetEntProp(ent, Prop_Data, "m_bShowInHUD"));
	
	//StartDisabled false
	SetEntProp(ent, Prop_Data, "m_bIsDisabled", 0);
	//start_paused false
	SetEntProp(ent, Prop_Data, "m_bStartPaused", 0);
	//timer_length 5min
	SetEntProp(ent, Prop_Data, "m_nTimerInitialLength", 10);
	//show_in_hud true
	SetEntProp(ent, Prop_Data, "m_bShowInHUD", 1);

	PrintToChat(client,"%d,%d,%d,%d",GetEntProp(ent, Prop_Data, "m_bIsDisabled"), GetEntProp(ent, Prop_Data, "m_bStartPaused"), GetEntProp(ent, Prop_Data, "m_nTimerInitialLength"), GetEntProp(ent, Prop_Data, "m_bShowInHUD"));
}

//HookEvent ラウンド開始時
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast){

	if(GetConVarInt(v_enable) == 0){
		return;
	}
	
	Func_PropLoad();
	
	//Entityを止める
	//CP停止
	Entity_Input("team_control_point_master","Disable");
	Entity_Input("team_control_point","Disable");
	Entity_Input("trigger_capture_area","Disable");
	Entity_Input("item_teamflag","Disable");
	Entity_Input("func_capturezone","Disable");
	
}

//EntityにInputを送信
public Entity_Input(String:classname[], String:Input[]){
	
	int ent = -1;  
 
	while ((ent = FindEntityByClassname(ent, classname)) != -1)  
	{
		int ref = EntIndexToEntRef(ent);
		AcceptEntityInput(ref, Input);
	}
	
}

//Function Propの読み込み
public Func_PropLoad(){
	
	new String:strMap[PLATFORM_MAX_PATH];
	new String:strArg[13][PLATFORM_MAX_PATH];
	
	new float:vec[3];
	new float:ang[3];
	
	new ent;
	
	GetCurrentMap(strMap,sizeof(strMap));
	Format(strMap,sizeof(strMap),"cfg/%s_prop.csv",strMap);
	
	new Handle:hFile = OpenFile(strMap,"r");
	if(hFile == INVALID_HANDLE){
		PrintToServer("[PropDemolition]ファイルが読み取り専用もしくは開いたままになっていませんか？ それかファイルがありません。");
		SetConVarInt(v_enable,0,false,false);
		return;
	}
	
	while(!IsEndOfFile(hFile)){
	
		//1行読み込む
		ReadFileLine(hFile,strMap,sizeof(strMap));
		
		//空行でなければ実行する
		if(StrEqual(strMap,"") == false){
		
			//csvをフィールドごとに配列に入れる
			if(ExplodeString(strMap, ",", strArg, 13, PLATFORM_MAX_PATH) == 13){
				
				ent = Func_PropSpawn(strArg[0],strArg[1],strArg[12]);
				if(ent == -1){
					PrintToServer("[PropSpawn]Propのロードに失敗しました。");
					PrintToServer("%s",strMap);
				}
				else{
					//Entityの情報を設定する
					vec[0] = StringToFloat(strArg[2]);
					vec[1] = StringToFloat(strArg[3]);
					vec[2] = StringToFloat(strArg[4]);
					ang[0] = StringToFloat(strArg[5]);
					ang[1] = StringToFloat(strArg[6]);
					ang[2] = StringToFloat(strArg[7]);
					
					SetEntProp(ent, Prop_Data, "m_nSkin", StringToInt(strArg[8]));
					SetEntProp(ent, Prop_Data, "m_iHealth", StringToInt(strArg[9]));
					SetEntProp(ent, Prop_Data, "m_nSolidType", StringToInt(strArg[10]));
					SetEntProp(ent, Prop_Data, "m_takedamage", StringToInt(strArg[11]));
					
					TeleportEntity(ent, vec, ang, NULL_VECTOR);
				}
			}
			else{
				PrintToServer("[PropSpawn]フィールド数がおかしいです。");
				PrintToServer("%s",strMap);
			}
		}
	}
}

//Function Prop出現処理
public Func_PropSpawn(String:Model[], String:Prop[], String:Team[]){

	new ent = CreateEntityByName(Prop);
	
	if(ent == -1){
		return ent;
	}
	
	new String:strName[PLATFORM_MAX_PATH];
	
	//Propにモデルを設定する
	SetEntPropString(ent, Prop_Data, "m_ModelName", Model);
	
	//チェックのために名前をつける 同じ名前は付けられない(破壊されていても)
	//TickCountでユニーク化する
	Format(strName,sizeof(strName),"pd_%s_%d",Team,GetGameTickCount());
	SetEntPropString(ent, Prop_Data, "m_iName", strName);
	
	//Propをスポーンさせる
	DispatchSpawn(ent)
	
	return ent;
}
