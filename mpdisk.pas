unit mpdisk;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, MasterPaskalForm, Dialogs, Forms, mpTime, FileUtil, LCLType,
  lclintf, controls, mpCripto, mpBlock, Zipper, mpLang, mpcoin, poolmanage,
  {$IFDEF WINDOWS}Win32Proc, {$ENDIF}
  mpminer;

Procedure VerificarArchivos();

// *** New files system
// Nodes file
Procedure CheckNodesFile();
Procedure CrearNodeFile();
Procedure CargarNodeFile();
Procedure VerifyCodedNodes();
Procedure SaveNodeFile();
Procedure FillNodeList();
Procedure UpdateNodeData(IPUser:String;Port:string;LastTime:String='');
// Except log file
Procedure CreateExceptlog();
Procedure ToExcLog(Texto:string);
Procedure SaveExceptLog();
// Pool payments file
Procedure CreatePoolPayfile();
Procedure AddPoolPay(Texto:string);
Procedure SavePoolPays();

Procedure CreateLog();
Procedure CreateADV(saving:boolean);
Procedure LoadADV();
Procedure ToLog(Texto:string);
Procedure SaveLog();
Procedure CrearArchivoOpciones();
Procedure CargarOpciones();
Procedure GuardarOpciones();
Procedure CrearIdiomaFile();
Procedure CargarIdioma(numero:integer);
Procedure CrearBotData();
Procedure DepurarBots();
Procedure CargarBotData();
Procedure UpdateBotData(IPUser:String);
Procedure SaveBotData();

Procedure CrearNTPData();
Procedure CargarNTPData();
Procedure SaveUpdatedFiles();
Procedure CrearWallet();
Procedure CargarWallet(wallet:String);
Procedure GuardarWallet();
Procedure UpdateWalletFromSumario();
Procedure CreateSumario();
Procedure CargarSumario();
Procedure GuardarSumario();
function GetMyLastUpdatedBlock():int64;
Procedure UpdateSumario(Direccion:string;monto:Int64;score:integer;LastOpBlock:string);
function SetCustomAlias(Address,Addalias:String;block:integer):Boolean;
procedure UnzipBlockFile(filename:String;delfile:boolean);
Procedure CreateResumen();
Procedure BuildHeaderFile(untilblock:integer);
Procedure AddBlockToSumary(BlockNumber:integer;SaveAndUpdate:boolean = true);
Procedure CompleteSumary();
Procedure RebuildSumario(UntilBlock:integer);
Procedure AddBlchHead(Numero: int64; hash,sumhash:string);
Procedure DelBlChHeadLast();
Procedure CrearMistrx();
Procedure CargarMisTrx();
Procedure SaveMyTrxsLastUpdatedblock(Number:integer;PoSPayouts, PoSEarnings:int64);
Procedure RebuildMyTrx(blocknumber:integer);
Procedure SaveMyTrxsToDisk(Cantidad:integer);
function NewMyTrx(aParam:Pointer):PtrInt;
Procedure CrearBatFileForRestart();
Procedure RestartNoso();
Procedure RunDiagnostico(linea:string);
Procedure CrearArchivoPoolInfo(nombre,direccion:string;porcentaje,miembros,port,tipo:integer;pass:string);
Procedure GuardarArchivoPoolInfo();
function GetPoolInfoFromDisk():PoolInfoData;
Procedure LoadPoolMembers();
Procedure CrearArchivoPoolMembers;
Procedure GuardarPoolMembers();
Procedure EjecutarAutoUpdate(version:string);
Procedure CrearRestartfile();
Procedure RestartConditions();
Procedure CrearCrashInfo();
function OSVersion: string;
{$IFDEF WINDOWS} Function GetWinVer():string; {$ENDIF}
Procedure RestoreBlockChain();
Procedure InitCrossValues();
function TryDeleteFile(filename:string):boolean;

implementation

Uses
  mpParser, mpGUI, mpRed;

// Complete file verification
Procedure VerificarArchivos();
var
  contador : integer;
Begin
LoadDefLangList();
if not directoryexists(BlockDirectory) then CreateDir(BlockDirectory);
OutText('✓ Block folder ok',false,1);
if not directoryexists(UpdatesDirectory) then CreateDir(UpdatesDirectory);
OutText('✓ Updates folder ok',false,1);

if not directoryexists(LogsDirectory) then CreateDir(LogsDirectory);
if not FileExists (ExceptLogFilename) then CreateExceptlog;
OutText('✓ Except Log file ok',false,1);

if not FileExists (AdvOptionsFilename) then CreateADV(false) else LoadADV();
UpdateRowHeigth();
OutText('✓ Advanced options loaded',false,1);
if not FileExists (ErrorLogFilename) then Createlog;
OutText('✓ Log file ok',false,1);

if not FileExists (UserOptions.wallet) then CrearWallet() else CargarWallet(UserOptions.wallet);
OutText('✓ Wallet file ok',false,1);
if not Fileexists(BotDataFilename) then CrearBotData() else CargarBotData();
OutText('✓ Bots file ok',false,1);

CheckNodesFile();
OutText('✓ Nodes file ok',false,1);

if not Fileexists(NTPDataFilename) then CrearNTPData() else CargarNTPData();
OutText('✓ NTP servers file ok',false,1);
if not Fileexists(SumarioFilename) then CreateSumario() else CargarSumario();
OutText('✓ Sumary file ok',false,1);
if not Fileexists(ResumenFilename) then CreateResumen();
OutText('✓ Headers file ok',false,1);
if not FileExists(BlockDirectory+'0.blk') then CrearBloqueCero();
if not FileExists(MyTrxFilename) then CrearMistrx() else CargarMisTrx();
OutText('✓ My transactions file ok',false,1);
if fileexists(PoolInfoFilename) then
   begin
   GetPoolInfoFromDisk();
   form1.TabMainPool.TabVisible:=true;
   if not FileExists(PoolPaymentsFilename) then CreatePoolPayfile();
   SetLength(PoolServerConex,PoolInfo.MaxMembers);
   SetLength(ArrayPoolMembers,PoolInfo.MaxMembers);
   for contador := 0 to length(PoolServerConex)-1 do
      begin
      PoolServerConex[contador] := Default(PoolUserConnection);
      ArrayPoolMembers[contador] := Default(PoolMembersData)
      end;
   GridPoolConex.RowCount:=PoolInfo.MaxMembers+1;
   form1.SG_PoolMiners.RowCount:=PoolInfo.MaxMembers+1;
   ConsoleLinesAdd('PoolMaxMembers:'+inttostr(length(PoolServerConex)));
   Miner_OwnsAPool := true;
   LoadPoolMembers();
   ResetPoolMiningInfo();
   PoolMembersTotalDeuda := GetTotalPoolDeuda();
   end;
if UserOptions.PoolInfo<> '' then
   begin
   LoadMyPoolData;
   end;
OutText('✓ Pool info verified',false,1);
MyLastBlock := GetMyLastUpdatedBlock;
BuildHeaderFile(MyLastBlock); // PROBABLY IT IS NOT NECESARY

UpdateWalletFromSumario();
OutText('✓ Wallet updated',false,1);
End;

// ***********************
// *** NEW FILE SYSTEM *** (0.2.0N and higher)
// ***********************

// *** NODE FILE ***

// Check procedure at launch
Procedure CheckNodesFile();
var
  leido : NodeData;
Begin
if not Fileexists(NodeDataFilename) then
   begin
   CrearNodeFile();
   end
else
   begin
   assignfile (FileNodeData,NodeDataFilename);
   Reset(FileNodeData);
   seek(FileNodeData,0);
   read (FileNodeData, Leido);
   closefile(FileNodeData);
   if leido.ip <> FileFormatVer then // this is to update old node files
      begin
      CrearNodeFile();
      end;
   end;
CargarNodeFile();
End;

// Creates node file
Procedure CrearNodeFile();
var
  nodoinicial : nodedata;
  continuar : boolean = true;
  contador : integer = 1;
  NodoStr : String;
Begin
   try
   assignfile(FileNodeData,NodeDataFilename);
   rewrite(FileNodeData);
   NodoInicial := Default(nodedata);
   NodoInicial.ip:= FileFormatVer;
   write(FileNodeData,nodoinicial);
   Repeat
     begin
     NodoStr := Parameter(DefaultNodes,contador);
     if NodoStr = '' then continuar := false
     else
        begin
        NodoInicial := Default(nodedata);
        NodoInicial.ip:=NodoStr;
        NodoInicial.port:='8080';
        NodoInicial.LastConexion:=UTCTime;
        write(FileNodeData,nodoinicial);
        contador := contador+1;
        end;
     end;
   until not continuar ;
   closefile(FileNodeData);
   SetLength(ListaNodos,0);
   Except on E:Exception do
         tolog ('Error creating node file');
   end;
End;

// Load nodes from disk
Procedure CargarNodeFile();
Var
  Leido : NodeData;
  contador: integer = 0;
Begin
   try
   assignfile (FileNodeData,NodeDataFilename);
   contador := 1;
   reset (FileNodeData);
   SetLength(ListaNodos,0);
   SetLength(ListaNodos, filesize(FileNodeData)-1);
   while contador < (filesize(FileNodeData)) do
      begin
      seek (FileNodeData, contador);
      read (FileNodeData, Leido);
      ListaNodos[contador-1] := Leido;
      contador := contador + 1;
      end;
   closefile(FileNodeData);
   Except on E:Exception do
         tolog ('Error loading node data');
   end;
VerifyCodedNodes();
End;

// Verify if all coded nodes are in the nodes files
Procedure VerifyCodedNodes();
var
  continuar : boolean = true;
  contador : integer = 1;
  NodoStr : String;
Begin
Repeat
   begin
   NodoStr := Parameter(DefaultNodes,contador);
   if NodoStr = '' then continuar := false
   else UpdateNodeData(NodoStr,'8080',UTCTime);
   contador := contador+1;
  end;
until not continuar;
End;

// Saves nodes to disk
Procedure SaveNodeFile();
Var
  contador : integer = 0;
Begin
setmilitime('SaveNodeFile',1);
   try
   assignfile (FileNodeData,NodeDataFilename);
   contador := 0;
   reset (FileNodeData);
   seek (FileNodeData, contador+1);
   if length(ListaNodos)>0 then
      begin
      for contador := 0 to length(ListaNodos)-1 do
         begin
         seek (FileNodeData, contador+1);
         write (FileNodeData, ListaNodos[contador]);
         end;
      end;
   truncate(FileNodeData);
   closefile(FileNodeData);
   S_NodeData := false;
   Except on E:Exception do
      tolog ('Error saving nodes to disk');
   end;
setmilitime('SaveNodeFile',2);
End;

// Fills options node list
Procedure FillNodeList();
var
  cont : integer;
Begin

End;

// Creates/updates a node
Procedure UpdateNodeData(IPUser:String;Port:string;LastTime:string='');
var
  contador : integer = 0;
  Existe : boolean = false;
Begin
S_NodeData := true;
if LastTime = '' then LastTime := UTCTime;
for contador := 0 to length(ListaNodos)-1 do
   begin
   if (ListaNodos[Contador].ip = IPUser)and (ListaNodos[Contador].port = port) then
      begin
      ListaNodos[Contador].LastConexion:=LastTime;
      S_NodeData := true;
      Existe := true;
      end;
   end;
if not Existe then
   begin
   SetLength(ListaNodos,Length(ListaNodos)+1);
   ListaNodos[Length(ListaNodos)-1].ip:=IPUser;
   ListaNodos[Length(ListaNodos)-1].port:=port;
   ListaNodos[Length(ListaNodos)-1].LastConexion:=LastTime;
   FillNodeList();
   S_NodeData := true;
   end;
End;

// *** EXCEPTLOG FILE ***

// Creates except log file
Procedure CreateExceptlog();
var
  archivo : textfile;
Begin
   try
   Assignfile(archivo, ExceptLogFilename);
   rewrite(archivo);
   Closefile(archivo);
   Except on E:Exception do
      tolog ('Error creating the log file');
   end;
End;

// Add Except log line
Procedure ToExcLog(Texto:string);
Begin
EnterCriticalSection(CSExcLogLines);
   try
   ExceptLines.Add(FormatDateTime('dd MMMM YYYY HH:MM:SS.zzz', Now)+' -> '+texto);
   except on E:Exception do begin end;
   end;
LeaveCriticalSection(CSExcLogLines);
S_Exc := true;
End;

// Save Except log file to disk
Procedure SaveExceptLog();
var
  archivo : textfile;
  IOCode : integer;
Begin
setmilitime('SaveExceptLog',1);
Assignfile(archivo, ExceptLogFilename);
{$I-}Append(archivo){$I+};
IOCode := IOResult;
If IOCode = 0 then
   begin
   EnterCriticalSection(CSExcLogLines);
      try
      while ExceptLines.Count>0 do
         begin
         Writeln(archivo, ExceptLines[0]);
         form1.MemoExceptLog.Lines.Add( ExceptLines[0]);
         NewExclogLines +=1;
         ExceptLines.Delete(0);
         end;
      S_Exc := false;
      Except on E:Exception do
         tolog ('Error saving the Except log file: '+E.Message);
      end;
   Closefile(archivo);
   LeaveCriticalSection(CSExcLogLines);
   end
else if IOCode = 5 then
   {$I-}Closefile(archivo){$I+};
setmilitime('SaveExceptLog',2);
End;

// *** Pool payments file ***

// Creates pool pays file
Procedure CreatePoolPayfile();
var
  archivo : textfile;
Begin
   try
   Assignfile(archivo, PoolPaymentsFilename);
   rewrite(archivo);
   Closefile(archivo);
   Except on E:Exception do
   tolog ('Error creating pool payments file');
   end;
End;

// Add Except log line
Procedure AddPoolPay(Texto:string);
Begin
EnterCriticalSection(CSPoolPay);
SetLength(ArrPoolPays,length(ArrPoolPays)+1);
ArrPoolPays[length(ArrPoolPays)-1].block:= StrToIntDef(parameter(texto,0),-1);
ArrPoolPays[length(ArrPoolPays)-1].address:=parameter(texto,1);
ArrPoolPays[length(ArrPoolPays)-1].amount:= StrToInt64Def(parameter(texto,2),0);
ArrPoolPays[length(ArrPoolPays)-1].Order:= parameter(texto,3);
PoolPaysLines.Add(texto);
LeaveCriticalSection(CSPoolPay);
S_PoolPays := true;
End;

// Save pool pays file to disk
Procedure SavePoolPays();
var
  archivo : textfile;
Begin
setmilitime('SavePoolPays',1);
Assignfile(archivo, PoolPaymentsFilename);
Append(archivo);
try
   while PoolPaysLines.Count>0 do
      begin
      Writeln(archivo, PoolPaysLines[0]);
      EnterCriticalSection(CSPoolPay);
      PoolPaysLines.Delete(0);
      LeaveCriticalSection(CSPoolPay);
      end;
   S_PoolPays := false;
Except on E:Exception do
   tolog ('Error saving Pool pays file');
end;
Closefile(archivo);
setmilitime('SavePoolPays',2);
End;

// *** BOTS FILE ***


// *****************************************************************************

// Creates log file
Procedure CreateLog();
var
  archivo : textfile;
Begin
   try
   Assignfile(archivo, ErrorLogFilename);
   rewrite(archivo);
   Closefile(archivo);
   Except on E:Exception do
      tolog ('Error creating the log file');
   end;
End;

// Creates/Saves Advopt file
Procedure CreateADV(saving:boolean);
Begin
setmilitime('CreateADV',1);
   try
   Assignfile(FileAdvOptions, AdvOptionsFilename);
   rewrite(FileAdvOptions);
   writeln(FileAdvOptions,'ctot '+inttoStr(ConnectTimeOutTime));
   writeln(FileAdvOptions,'rtot '+inttoStr(ReadTimeOutTIme));
   writeln(FileAdvOptions,'UserFontSize '+inttoStr(UserFontSize));
   writeln(FileAdvOptions,'UserRowHeigth '+inttoStr(UserRowHeigth));
   writeln(FileAdvOptions,'CPUs '+inttoStr(DefCPUs));
   writeln(FileAdvOptions,'PoolExpel '+inttoStr(PoolExpelBlocks));
   writeln(FileAdvOptions,'PoolShare '+inttoStr(PoolShare));
   writeln(FileAdvOptions,'RPCPort '+inttoStr(RPCPort));
   writeln(FileAdvOptions,'RPCPass '+RPCPass);
   writeln(FileAdvOptions,'ShowedOrders '+IntToStr(ShowedOrders));
   writeln(FileAdvOptions,'MaxPeers '+IntToStr(MaxPeersAllow));
   writeln(FileAdvOptions,'PoolStepsDeep '+IntToStr(PoolStepsDeep));
   writeln(FileAdvOptions,'AutoConnect '+BoolToStr(WO_AutoConnect,true));
   writeln(FileAdvOptions,'AutoServer '+BoolToStr(WO_AutoServer,true));
   writeln(FileAdvOptions,'ToTray '+BoolToStr(WO_ToTray,true));
   writeln(FileAdvOptions,'MinConexToWork '+IntToStr(MinConexToWork));
   writeln(FileAdvOptions,'PosWarning '+IntToStr(WO_PosWarning));
   writeln(FileAdvOptions,'AntiFreeze '+BoolToStr(WO_AntiFreeze,true));
   writeln(FileAdvOptions,'MultiSend '+BoolToStr(WO_MultiSend,true));
   writeln(FileAdvOptions,'AntifreezeTime '+IntToStr(WO_AntifreezeTime));
   writeln(FileAdvOptions,'RPCFilter '+BoolToStr(RPCFilter,true));
   writeln(FileAdvOptions,'RPCWhiteList '+RPCWhitelist);
   writeln(FileAdvOptions,'RPCAuto '+BoolToStr(RPCAuto,true));

   Closefile(FileAdvOptions);
   if saving then tolog('Options file saved');
   S_AdvOpt := false;
   Except on E:Exception do
      toexclog ('Error creating AdvOpt file');
   end;
   setmilitime('CreateADV',2);
End;

// Loads Advopt values
Procedure LoadADV();
var
  linea:string;
Begin
   try
   Assignfile(FileAdvOptions, AdvOptionsFilename);
   reset(FileAdvOptions);
   while not eof(FileAdvOptions) do
      begin
      readln(FileAdvOptions,linea);
      if parameter(linea,0) ='ctot' then ConnectTimeOutTime:=StrToIntDef(Parameter(linea,1),ConnectTimeOutTime);
      if parameter(linea,0) ='rtot' then ReadTimeOutTIme:=StrToIntDef(Parameter(linea,1),ReadTimeOutTIme);
      if parameter(linea,0) ='UserFontSize' then UserFontSize:=StrToIntDef(Parameter(linea,1),UserFontSize);
      if parameter(linea,0) ='UserRowHeigth' then UserRowHeigth:=StrToIntDef(Parameter(linea,1),UserRowHeigth);
      if parameter(linea,0) ='CPUs' then DefCPUs:=StrToIntDef(Parameter(linea,1),DefCPUs);
      if parameter(linea,0) ='PoolExpel' then PoolExpelBlocks:=StrToIntDef(Parameter(linea,1),PoolExpelBlocks);
      if parameter(linea,0) ='PoolShare' then PoolShare:=StrToIntDef(Parameter(linea,1),PoolShare);
      if parameter(linea,0) ='RPCPort' then RPCPort:=StrToIntDef(Parameter(linea,1),RPCPort);
      if parameter(linea,0) ='RPCPass' then RPCPass:=Parameter(linea,1);
      if parameter(linea,0) ='ShowedOrders' then ShowedOrders:=StrToIntDef(Parameter(linea,1),ShowedOrders);
      if parameter(linea,0) ='MaxPeers' then MaxPeersAllow:=StrToIntDef(Parameter(linea,1),MaxPeersAllow);
      if parameter(linea,0) ='PoolStepsDeep' then PoolStepsDeep:=StrToIntDef(Parameter(linea,1),PoolStepsDeep);
      if parameter(linea,0) ='AutoConnect' then WO_AutoConnect:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='AutoServer' then WO_AutoServer:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='ToTray' then WO_ToTray:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='MinConexToWork' then MinConexToWork:=StrToIntDef(Parameter(linea,1),MinConexToWork);
      if parameter(linea,0) ='PosWarning' then WO_PosWarning:=StrToIntDef(Parameter(linea,1),WO_PosWarning);
      if parameter(linea,0) ='AntiFreeze' then WO_AntiFreeze:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='MultiSend' then WO_MultiSend:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='AntifreezeTime' then WO_AntifreezeTime:=StrToIntDef(Parameter(linea,1),WO_AntifreezeTime);
      if parameter(linea,0) ='RPCFilter' then RPCFilter:=StrToBool(Parameter(linea,1));
      if parameter(linea,0) ='RPCWhiteList' then RPCWhiteList:=Parameter(linea,1);
      if parameter(linea,0) ='RPCAuto' then RPCAuto:=StrToBool(Parameter(linea,1));

      end;
   Closefile(FileAdvOptions);
   Except on E:Exception do
      tolog ('Error creating AdvOpt file');
   end;
End;

// Add log line
Procedure ToLog(Texto:string);
Begin
EnterCriticalSection(CSLoglines);
   try
   LogLines.Add(timetostr(now)+': '+texto);
   S_Log := true;
   Except on E:Exception do
      begin

      end;
   end;
LeaveCriticalSection(CSLoglines);
End;

// Save log files to disk
Procedure SaveLog();
var
  archivo : textfile;
  IOCode : integer;
Begin
setmilitime('SaveLog',1);
Assignfile(archivo, ErrorLogFilename);
{$I-}Append(archivo);{$I+}
IOCode := IOResult;
if IOCode = 0 then
   begin
   EnterCriticalSection(CSLoglines);
      try
      while LogLines.Count>0 do
         begin
         Writeln(archivo,LogLines[0]);
         form1.MemoLog.Lines.Add(LogLines[0]);
         if not formlog.Visible then NewLogLines := NewLogLines+1;
         LogLines.Delete(0);
         end;
      S_Log := false;
      Except on E:Exception do
         toExclog ('Error saving to the log file: '+E.Message);
      end;
   Closefile(archivo);
   LeaveCriticalSection(CSLoglines);
   end
else if IOCode = 5 then
   {$I-}Closefile(archivo){$I+};
setmilitime('SaveLog',2);
End;

// Creates options file
Procedure CrearArchivoOpciones();
var
  DefOptions : Options;
Begin
   try
   assignfile(FileOptions,OptionsFileName);
   rewrite(FileOptions);
   DefOptions.language:=0;
   DefOptions.Port:=8080;
   DefOptions.GetNodes:=false;
   DefOptions.PoolInfo := '';
   DefOptions.wallet:= 'NOSODATA'+DirectorySeparator+'wallet.pkw';
   DefOptions.AutoServer:=false;
   DefOptions.AutoConnect:=true;
   DefOptions.Auto_Updater:=false;
   DefOptions.JustUpdated:=false;
   DefOptions.VersionPage:='https://nosocoin.com';
   DefOptions.ToTray:=false;
   DefOptions.UsePool:=false;
   write(FileOptions,DefOptions);
   closefile(FileOptions);
   UserOptions := DefOptions;
   OutText('✓ Options file created',false,1);
   Except on E:Exception do
      tolog ('Error creating options file');
   end;
End;

// Load options from disk
Procedure CargarOpciones();
Begin
   try
   assignfile(FileOptions,OptionsFileName);
   reset(FileOptions);
   read(FileOptions,UserOptions);
   closefile(FileOptions);
   OutText('✓ Options file loaded',false,1);
   Except on E:Exception do
      tolog ('Error loading user options');
   end;
End;

// Save Options to disk
Procedure GuardarOpciones();
Begin
setmilitime('GuardarOpciones',1);
   try
   assignfile(FileOptions,OptionsFileName);
   reset(FileOptions);
   seek(FileOptions,0);
   write(FileOptions,UserOptions);
   closefile(FileOptions);
   S_Options := false;
   Except on E:Exception do
      tolog ('Error saving user options');
   end;
   setmilitime('GuardarOpciones',2);
End;

// Creates the default language file
Procedure CrearIdiomaFile();
Begin
   try
   CrearArchivoLang();
   CargarIdioma(0);
   ConsoleLinesAdd(LangLine(18));
   OutText('✓ Language file created',false,1);
   Except on E:Exception do
      tolog ('Error creating default language file');
   end;
End;

// Loads an specified language
Procedure CargarIdioma(numero:integer);
var
  archivo : file of string[255];
  datoleido : string[255] = '';
  Idiomas : integer = 0;
  StartPos : integer = 0;
  Registros : integer = 0;
  Lineas : integer = 0;
  contador : integer = 0;
Begin
   try
   if FileExists(LanguageFileName) then
      begin
      AssignFile(Archivo,LanguageFileName);
      reset(archivo);
      Registros := filesize(archivo);
      seek(archivo,0);read(archivo,datoleido);
      idiomas := CadToNum(Datoleido,1,'Failed Converting language number: '+Datoleido);
      if numero > Idiomas-1 then // El idioma especificado no existe
         begin
         closefile(archivo);
         exit;
         end;
      StringListLang.Clear;
      IdiomasDisponibles.Clear;
      for contador := 1 to idiomas do
         begin
         seek(archivo,contador);read(archivo,datoleido);
         IdiomasDisponibles.Add(datoleido);
         end;
      seek(archivo,1+numero);read(archivo,datoleido);
      CurrentLanguage := datoleido;
      Lineas := (Registros - 1 - idiomas) div idiomas;
      LanguageLines := lineas;
      StartPos := (1+idiomas)+(lineas*numero);
      for contador := 0 to lineas-1 do
         begin
         seek(archivo,startpos+contador);read(archivo,datoleido);
         StringListLang.Add(datoleido);
         end;
      closefile(archivo);
      if not G_Launching then
         begin
         InicializarGUI();
         BNewAddr.Hint:=LAngLine(64);BCopyAddr.Hint:=LAngLine(65);BSendCoins.Hint:=LangLine(66);
         LSCTop.Caption:=LangLine(66);SBSCPaste.hint:=LangLine(67);SBSCMax.hint:=LangLine(68);
         SCBitClea.Caption:=LangLine(69);SCBitSend.Caption:=LangLine(70);SCBitCancel.Caption:=LangLine(71);
         SCBitConf.Caption:=LangLine(72);BitInfoTrx.hint:=LangLine(73);
         end;
      UserOptions.language:=numero;
      S_Options := true;
      if G_Launching then OutText('✓ Language file loaded',false,1);
      end
   else // si el archivo no existe
      begin
      ConsoleLinesAdd('noso.lng not found');
      tolog('noso.lng not found');
      end
   Except on E:Exception do
      tolog ('Error loading language file');
   end;
End;

// Creates bots file
Procedure CrearBotData();
Begin
   try
   assignfile(FileBotData,BotDataFilename);
   rewrite(FileBotData);
   closefile(FileBotData);
   SetLength(ListadoBots,0);
   Except on E:Exception do
      tolog ('Error creating bot data');
   end;
End;

// Load bots from file
Procedure CargarBotData();
Var
  Leido : BotData;
  contador: integer = 0;
Begin
   try
   assignfile (FileBotData,BotDataFilename);
   contador := 0;
   reset (FileBotData);
   SetLength(ListadoBots,0);
   SetLength(ListadoBots, filesize(FileBotData));
   while contador < (filesize(FileBotData)) do
      begin
      seek (FileBotData, contador);
      read (FileBotData, Leido);
      ListadoBots[contador] := Leido;
      contador := contador + 1;
      end;
   closefile(FileBotData);
   //DepurarBots();
   Except on E:Exception do
      tolog ('Error loading bot data');
   end;
End;

// Bot info debug
Procedure DepurarBots();
var
  contador : integer = 0;
  LimiteTiempo : Int64 = 0;
  NodeDeleted : boolean;
Begin
LimiteTiempo := CadToNum(UTCTime,0,'Failed converting UTC time on depurarbots')-2592000; // Los menores que esto deben ser eliminados(2592000 un mes)
While contador < length(ListadoBots)-1 do
   begin
   NodeDeleted := false;
   if CadToNum(ListadoBots[contador].LastRefused,999999999999,'Failed converting last refused on depurarbots: '+ListadoBots[contador].LastRefused) < LimiteTiempo then
      Begin
      Delete(ListadoBots,Contador,1);
      contador := contador-1;
      NodeDeleted := true;
      end;
   if not NodeDeleted then contador := contador+1;
   end;
S_BotData := true;
End;

// Modifica la hora del ultimo intento del bot, o lo añade si es la primera vez
Procedure UpdateBotData(IPUser:String);
var
  contador : integer = 0;
  updated : boolean = false;
Begin
for contador := 0 to length(ListadoBots)-1 do
   begin
   if ListadoBots[Contador].ip = IPUser then
      begin
      ListadoBots[Contador].LastRefused:=UTCTime;
      Updated := true;
      end;
   end;
if not updated then
   begin
   SetLength(ListadoBots,Length(ListadoBots)+1);
   ListadoBots[Length(listadoBots)-1].ip:=IPUser;
   ListadoBots[Length(listadoBots)-1].LastRefused:=UTCTime;
   end;
S_BotData := true;
End;

// Save bots to disk
Procedure SaveBotData();
Var
  contador : integer = 0;
Begin
setmilitime('SaveBotData',1);
   try
   assignfile (FileBotData,BotDataFilename);
   contador := 0;
   reset (FileBotData);
   if length(ListadoBots) > 0 then
      begin
   for contador := 0 to length(ListadoBots)-1 do
         begin
         seek (FileBotData, contador);
         write (FileBotData, ListadoBots[contador]);
         end;
      end;
   Truncate(FileBotData);
   closefile(FileBotData);
   S_BotData := false;
   tolog ('Bot file saved: '+inttoStr(length(ListadoBots))+' registers');
   Except on E:Exception do
         tolog ('Error saving bots to file :'+E.Message);
   end;
setmilitime('SaveBotData',2);
End;

// Creates NTP servers file
Procedure CrearNTPData();
Var
  contador : integer = 0;
Begin
   try
   assignfile(FileNTPData,NTPDataFilename);
   setlength(ListaNTP,11);
   ListaNTP[0].host := 'ntp.amnic.net'; ListaNTP[0].LastUsed:='0';
   ListaNTP[1].host := 'ts2.aco.net'; ListaNTP[1].LastUsed:='0';
   ListaNTP[2].host := 'hora.roa.es'; ListaNTP[2].LastUsed:='0';
   ListaNTP[3].host := 'ntp.atomki.mta.hu'; ListaNTP[3].LastUsed:='0';
   ListaNTP[4].host := 'time.esa.int'; ListaNTP[4].LastUsed:='0';
   ListaNTP[5].host := 'time.stdtime.gov.tw'; ListaNTP[5].LastUsed:='0';
   ListaNTP[6].host := 'stratum-1.sjc02.svwh.net'; ListaNTP[6].LastUsed:='0';
   ListaNTP[7].host := 'ntp3.indypl.org'; ListaNTP[7].LastUsed:='0';
   ListaNTP[8].host := 'ntp1.sp.se'; ListaNTP[8].LastUsed:='0';
   ListaNTP[9].host := 'ntp.ntp-servers.com'; ListaNTP[9].LastUsed:='0';
   ListaNTP[10].host := '1.de.pool.ntp.org'; ListaNTP[10].LastUsed:='0';
   rewrite(FileNTPData);
   for contador := 0 to 9 do
      begin
      seek (FileNTPData,contador);
      write(FileNTPData,ListaNTP[contador]);
      end;
   closefile(FileNTPData);
   Except on E:Exception do
      tolog ('Error creating NTP servers file');
   end;
End;

// Load NTP servers
Procedure CargarNTPData();
Var
  contador : integer = 0;
Begin
   try
   assignfile(FileNTPData,NTPDataFilename);
   reset(FileNTPData);
   setlength(ListaNTP,filesize(FileNTPData));
   for contador := 0 to filesize(FileNTPData)-1 do
      begin
      seek(FileNTPData,contador);
      Read(FileNTPData,ListaNTP[contador]);
      end;
   closefile(FileNTPData);
   Except on E:Exception do
      tolog ('Error loading NTP servers');
   end;
End;

// Saves updates files to disk
Procedure SaveUpdatedFiles();
Begin
if S_BotData then SaveBotData();
if S_NodeData then SaveNodeFile();
if S_Options then GuardarOpciones();
if S_Wallet then GuardarWallet();
if S_Sumario then GuardarSumario();
if S_PoolMembers then GuardarPoolMembers();
if S_Log then SaveLog;
if S_Exc then SaveExceptLog;
if S_PoolPays then SavePoolPays;
if S_PoolInfo then GuardarArchivoPoolInfo;
if S_AdvOpt then CreateADV(true);
End;

// Creates a new wallet
Procedure CrearWallet();
Begin
   try
   if not fileexists (WalletFilename) then // asegurarse de no borrar una cartera previa
      begin
      assignfile(FileWallet,WalletFilename);
      setlength(ListaDirecciones,1);
      rewrite(FileWallet);
      listadirecciones[0] := CreateNewAddress();
      seek(FileWallet,0);
      write(FileWallet,listadirecciones[0]);
      closefile(FileWallet);
      end;
   UserOptions.Wallet:=WalletFilename;
   if FileExists(MyTrxFilename) then DeleteFile(MyTrxFilename);
   S_Options := true;
   Except on E:Exception do
      tolog ('Error creating wallet file');
   end;
End;

// Load a wallet from disk
Procedure CargarWallet(wallet:String);
var
  contador : integer = 0;
Begin
   try
   if fileExists(wallet) then
      begin
      assignfile(FileWallet,Wallet);
      setlength(ListaDirecciones,0);
      reset(FileWallet);
      setlength(ListaDirecciones,FileSize(FileWallet));
      for contador := 0 to Length(ListaDirecciones)-1 do
         begin
         seek(FileWallet,contador);
         Read(FileWallet,ListaDirecciones[contador]);
         ListaDirecciones[contador].Pending:=0;
         end;
      closefile(FileWallet);
      end;
   UpdateWalletFromSumario();
   GuardarWallet();                         // Permite corregir cualquier problema con los pending
   Except on E:Exception do
      tolog ('Error loading wallet from file');
   end;
End;

// Save wallet data to disk
Procedure GuardarWallet();
var
  contador : integer = 0;
  previous : int64;
Begin
setmilitime('GuardarWallet',1);
copyfile (UserOptions.Wallet,UserOptions.Wallet+'.bak');
assignfile(FileWallet,UserOptions.Wallet);
reset(FileWallet);
   try
   for contador := 0 to Length(ListaDirecciones)-1 do
      begin
      seek(FileWallet,contador);
      Previous := ListaDirecciones[contador].Pending;
      ListaDirecciones[contador].Pending := 0;
      write(FileWallet,ListaDirecciones[contador]);
      ListaDirecciones[contador].Pending := Previous;
      end;
   S_Wallet := false;
   Except on E:Exception do
      tolog ('Error saving wallet to disk ('+E.Message+')');
   end;
closefile(FileWallet);
setmilitime('GuardarWallet',2);
End;

// Updates wallet addresses balance from sumary
Procedure UpdateWalletFromSumario();
var
  Contador, counter : integer;
  ThisExists : boolean = false;
Begin
for contador := 0 to length(ListaDirecciones)-1 do
   begin
   ThisExists := false;
   for counter := 0 to length(ListaSumario)-1 do
      begin
      if ListaDirecciones[contador].Hash = ListaSumario[counter].Hash then
         begin
         ListaDirecciones[contador].Balance:=ListaSumario[counter].Balance;
         ListaDirecciones[contador].LastOP:=ListaSumario[counter].LastOP;
         ListaDirecciones[contador].score:=ListaSumario[counter].score;
         ListaDirecciones[contador].Custom:=ListaSumario[counter].Custom;
         ThisExists := true;
         end;
      end;
   if not ThisExists then
      begin
      ListaDirecciones[contador].Balance:=0;
      ListaDirecciones[contador].LastOP:=0;
      ListaDirecciones[contador].score:=0;
      ListaDirecciones[contador].Custom:='';
      end;
   end;
S_Wallet := true;
U_Dirpanel := true;
End;

// Creates sumary file
Procedure CreateSumario();
Begin
   try
   SetLength(ListaSumario,0);
   assignfile(FileSumario,SumarioFilename);
   Rewrite(FileSumario);
   CloseFile(FileSumario);
   // for cases when rebuilding sumary
   if FileExists(BlockDirectory+'0.blk') then UpdateSumario(ADMINHash,PremineAmount,0,'0');
   Except on E:Exception do
      tolog ('Error creating sumary file');
   end;
End;

// Loads sumary from disk
Procedure CargarSumario();
var
  contador : integer = 0;
Begin
   TRY
   SetLength(ListaSumario,0);
   assignfile(FileSumario,SumarioFilename);
   Reset(FileSumario);
   SetLength(ListaSumario,fileSize(FileSumario));
   for contador := 0 to Filesize(fileSumario)-1 do
      Begin
      seek(filesumario,contador);
      read(FileSumario,Listasumario[contador]);
      end;
   CloseFile(FileSumario);
   EXCEPT on E:Exception do
      tolog ('Error loading sumary from file');
   END;
End;

// Save sumary to disk
Procedure GuardarSumario();
var
  contador : integer = 0;
Begin
setmilitime('GuardarSumario',1);
SetCurrentJob('GuardarSumario',true);
EnterCriticalSection(CSSumary);
assignfile(FileSumario,SumarioFilename);
   try
   Reset(FileSumario);
   for contador := 0 to length(ListaSumario)-1 do
      Begin
      seek(filesumario,contador);
      write(FileSumario,Listasumario[contador]);
      end;
   Truncate(filesumario);
   MySumarioHash := HashMD5File(SumarioFilename);
   S_Sumario := false;
   U_DataPanel := true;
   Except on E:Exception do
      tolog ('Error saving sumary file');
   end;
CloseFile(FileSumario);
LeaveCriticalSection(CSSumary);
SetCurrentJob('GuardarSumario',false);
setmilitime('GuardarSumario',2);
End;

// Returns the last downloaded block
function GetMyLastUpdatedBlock():int64;
Var
  BlockFiles : TStringList;
  contador : int64 = 0;
  LastBlock : int64 = 0;
  OnlyNumbers : String;
Begin
   try
   BlockFiles := TStringList.Create;
   FindAllFiles(BlockFiles, BlockDirectory, '*.blk', true);
   while contador < BlockFiles.Count do
      begin
      OnlyNumbers := copy(BlockFiles[contador], 17, length(BlockFiles[contador])-20);
      if CadToNum(OnlyNumbers,0,'Failed converting block to number:'+OnlyNumbers) > Lastblock then
         LastBlock := CadToNum(OnlyNumbers,0,'Failed converting block to number:'+OnlyNumbers);
      contador := contador+1;
      end;
   BlockFiles.Free;
   Result := LastBlock;
   Except on E:Exception do
      tolog ('Error getting my last updated block');
   end;
end;

// Updates sumary
Procedure UpdateSumario(Direccion:string;monto:Int64;score:integer;LastOpBlock:string);
var
  contador : integer = 0;
  Yaexiste : boolean = false;
  NuevoRegistro : SumarioData;
Begin
EnterCriticalSection(CSSumary);
for contador := 0 to length(ListaSumario)-1 do
   begin
   if ((ListaSumario[contador].Hash=Direccion) or (ListaSumario[contador].Custom=Direccion)) then
      begin
      NuevoRegistro := Default(SumarioData);
      NuevoRegistro.Hash:=ListaSumario[contador].Hash;
      NuevoRegistro.Custom:=ListaSumario[contador].Custom;
      NuevoRegistro.Balance:=ListaSumario[contador].Balance+Monto;
      NuevoRegistro.Score:=ListaSumario[contador].Score+score;;
      NuevoRegistro.LastOP:=CadToNum(LastOpBlock,0,'**CRITICAL: STI fail lastop on update sumario:'+LastOpBlock);
      ListaSumario[contador] := NuevoRegistro;
      Yaexiste := true;
      break;
      end;
   end;
if not YaExiste then
   begin
   NuevoRegistro := Default(SumarioData);
   setlength(ListaSumario,Length(ListaSumario)+1);
   NuevoRegistro.Hash:=Direccion;
   NuevoRegistro.Custom:='';
   NuevoRegistro.Balance:=Monto;
   NuevoRegistro.Score:=0;
   NuevoRegistro.LastOP:=CadToNum(LastOpBlock,0,'**CRITICAL: STI fail lastop on update sumario:'+LastOpBlock);
   ListaSumario[length(listasumario)-1] := NuevoRegistro;
   end;
S_Sumario := true;
LeaveCriticalSection(CSSumary);
if DireccionEsMia(Direccion)>= 0 then UpdateWalletFromSumario();
End;

// Set alias for an address it it is empty
function SetCustomAlias(Address,Addalias:String;block:integer):boolean;
var
  cont : integer;
Begin
result := false;
EnterCriticalSection(CSSumary);
for cont := 0 to length(ListaSumario)-1 do
   begin
   if ((ListaSumario[cont].Hash=Address)and (ListaSumario[cont].custom='')) then
      begin
      listasumario[cont].Custom:=Addalias;
      listasumario[cont].LastOP:=block;
      result := true;
      break;
      end;
   end;
LeaveCriticalSection(CSSumary);
if block > 10429 then
   toexclog('Error assigning custom alias to address: '+Address+' -> '+addalias);
End;

// Unzip a zip file and (optional) delete it
procedure UnzipBlockFile(filename:String;delFile:boolean);
var
  UnZipper: TUnZipper;
begin
   try
   UnZipper := TUnZipper.Create;
      try
      UnZipper.FileName := filename;
      UnZipper.OutputPath := '';
      UnZipper.Examine;
      UnZipper.UnZipAllFiles;
      finally
      UnZipper.Free;
      end;
   if delfile then Trydeletefile(filename);
   Except on E:Exception do
      begin
      tolog ('Error unzipping block file');
      end;
   end;
end;

// Creates header file
Procedure CreateResumen();
Begin
   try
   assignfile(FileResumen,ResumenFilename);
   rewrite(FileResumen);
   closefile(FileResumen);
   Except on E:Exception do
      tolog ('Error creating headers file');
   end;
End;

// Rebuild headers file
Procedure BuildHeaderFile(untilblock:integer);
var
  Dato, NewDato: ResumenData;
  Contador : integer = 0;
  CurrHash : String = '';
  LastHash : String = '';
  BlockHeader : BlockHeaderData;
  ArrayOrders : BlockOrdersArray;
  cont : integer;
  newblocks : integer = 0;
Begin
assignfile(FileResumen,ResumenFilename);
reset(FileResumen);
ConsoleLinesAdd(LangLine(127)+IntToStr(untilblock)); //'Rebuilding until block '
contador := MyLastBlock;
while contador <= untilblock do
   begin
   if ((contador = MyLastBlock) and (contador>0)) then
      LastHash := HashMD5File(BlockDirectory+IntToStr(MyLastBlock-1)+'.blk');
   info(LangLine(127)+IntToStr(contador)); //'Rebuild block: '
   BlockHeader := LoadBlockDataHeader(contador);
   dato := default(ResumenData);
   seek(FileResumen,contador);
   if filesize(FileResumen)>contador then
      Read(FileResumen,dato);
   If ((contador>0) and (BlockHeader.LastBlockHash <> LastHash)) then
      begin  // Que hacer si todo encaja pero el sumario no esta bien
      RestoreBlockChain();
      end;
   CurrHash := HashMD5File(BlockDirectory+IntToStr(contador)+'.blk');
   if  CurrHash <> Dato.blockhash then
      begin
      NewDato := Default(ResumenData);
      NewDato := Dato;
      NewDato.block:=contador;
      NewDato.blockhash:=CurrHash;
      seek(FileResumen,contador);
      Write(FileResumen,Newdato);
      end;
   if contador > ListaSumario[0].LastOP then // el bloque analizado es mayor que el ultimo incluido
      begin                                  // en el sumario asi que se procesan sus trxs
      newblocks := newblocks + 1;
      AddBlockToSumary(contador);
      {UpdateSumario(BlockHeader.AccountMiner,BlockHeader.Reward+BlockHeader.MinerFee,0,IntToStr(contador));
      // AQUI LEER LAS TRANSACCIONES Y PROCESARLAS
      ArrayOrders := Default(BlockOrdersArray);
      ArrayOrders := GetBlockTrxs(contador);
      for cont := 0 to length(ArrayOrders)-1 do
         begin
         if ArrayOrders[cont].OrderType='CUSTOM' then
            begin
            UpdateSumario(ArrayOrders[cont].Sender,Restar(Customizationfee),0,IntToStr(contador));
            setcustomalias(ArrayOrders[cont].Sender,ArrayOrders[cont].Receiver);
            end;
         if ArrayOrders[cont].OrderType='TRFR' then
            begin
            UpdateSumario(ArrayOrders[cont].Sender,Restar(ArrayOrders[cont].AmmountFee+ArrayOrders[cont].AmmountTrf),0,IntToStr(contador));
            UpdateSumario(ArrayOrders[cont].Receiver,ArrayOrders[cont].AmmountTrf,0,IntToStr(contador));
            end;
         end;
      ListaSumario[0].LastOP:=contador;
      GuardarSumario(); }
      end;
   // VErificar si el sumario hash no esta en blanco
   seek(FileResumen,contador);
   Read(FileResumen,dato);
   if dato.SumHash = '' then
      begin
      NewDato := Default(ResumenData);
      NewDato := Dato;
      NewDato.SumHash:=HashMD5File(SumarioFilename);
      seek(FileResumen,contador);
      Write(FileResumen,Newdato);
      tolog ('Readjusted sumhash for block '+inttostr(contador));
      end;
   contador := contador+1;
   LastHash := CurrHash;
   end;
while filesize(FileResumen)> Untilblock+1 do  // cabeceras presenta un numero anomalo de registros
   begin
   seek(FileResumen,Untilblock+1);
   truncate(fileResumen);
   tolog ('Readjusted headers size');
   end;
closefile(FileResumen);
if newblocks>0 then
   begin
   ConsoleLinesAdd(IntToStr(newblocks)+LangLine(129)); //' added to headers'
   U_Mytrxs := true;
   U_DirPanel := true;
   end;
GuardarSumario();
UpdateMyData();
MySumarioHash := HashMD5File(SumarioFilename);
U_Dirpanel := true;
if g_launching then OutText('✓ '+IntToStr(untilblock+1)+' blocks rebuilded',false,1);
End;

// COmpletes the sumary from LAstUpdate to Lastblock
Procedure CompleteSumary();
var
  StartBlock, finishblock : integer;
  counter : integer;
Begin
SetCurrentJob('CompleteSumary',true);
RebuildingSumary := true;
StartBlock := ListaSumario[0].LastOP+1;
finishblock := Mylastblock;
for counter := StartBlock to finishblock do
   begin
   info(LangLine(130)+inttoStr(counter));  //'Rebuilding sumary block: '
   application.ProcessMessages;
   EngineLastUpdate := UTCTime.ToInt64;
   AddBlockToSumary(counter, false);
   end;
SetCurrentJob('save',true);
GuardarSumario();
SetCurrentJob('save',false);
RebuildingSumary := false;
UpdateMyData();
ConsoleLinesAdd('Sumary completed from '+IntToStr(StartBlock)+' to '+IntToStr(finishblock));
SetCurrentJob('CompleteSumary',false);
RebuildMyTrx(finishblock);
info('Sumary completed');
End;

// Add 1 block transactions to sumary
Procedure AddBlockToSumary(BlockNumber:integer;SaveAndUpdate:boolean = true);
var
  cont : integer;
  BlockHeader : BlockHeaderData;
  ArrayOrders : BlockOrdersArray;
  ArrayPos    : BlockArraysPos;
  PosReward   : int64;
  PosCount    : integer;
  CounterPos  : integer;
Begin
SetCurrentJob('AddBlockToSumary'+inttostr(BlockNumber),true);
BlockHeader := Default(BlockHeaderData);
BlockHeader := LoadBlockDataHeader(BlockNumber);
EnterCriticalSection(CSSumary);
UpdateSumario(BlockHeader.AccountMiner,BlockHeader.Reward+BlockHeader.MinerFee,0,IntToStr(BlockNumber));
ArrayOrders := Default(BlockOrdersArray);
ArrayOrders := GetBlockTrxs(BlockNumber);
for cont := 0 to length(ArrayOrders)-1 do
   begin
   if ArrayOrders[cont].OrderType='CUSTOM' then
      begin
      UpdateSumario(ArrayOrders[cont].Sender,Restar(Customizationfee),0,IntToStr(BlockNumber));
      setcustomalias(ArrayOrders[cont].Sender,ArrayOrders[cont].Receiver,BlockNumber);
      end;
   if ArrayOrders[cont].OrderType='TRFR' then
      begin
      UpdateSumario(ArrayOrders[cont].Sender,Restar(ArrayOrders[cont].AmmountFee+ArrayOrders[cont].AmmountTrf),0,IntToStr(BlockNumber));
      UpdateSumario(ArrayOrders[cont].Receiver,ArrayOrders[cont].AmmountTrf,0,IntToStr(BlockNumber));
      end;
   end;
setlength(ArrayOrders,0);
if blocknumber >= PoSBlockStart then
   begin
   ArrayPos := GetBlockPoSes(BlockNumber);
   PosReward := StrToIntDef(Arraypos[length(Arraypos)-1].address,0);
   SetLength(ArrayPos,length(ArrayPos)-1);
   PosCount := length(ArrayPos);
   for counterpos := 0 to PosCount-1 do
      UpdateSumario(ArrayPos[counterPos].address,Posreward,0,IntToStr(BlockNumber));
   UpdateSumario(BlockHeader.AccountMiner,Restar(PosCount*Posreward),0,IntToStr(BlockNumber));
   SetLength(ArrayPos,0);
   end;
ListaSumario[0].LastOP:=BlockNumber;
if SaveAndUpdate then
   begin
   GuardarSumario();
   UpdateMyData();
   end;
LeaveCriticalSection(CSSumary);
SetCurrentJob('AddBlockToSumary'+inttostr(BlockNumber),false);
End;

// Rebuilds totally sumary
Procedure RebuildSumario(UntilBlock:integer);
var
  contador, cont : integer;
  BlockHeader : BlockHeaderData;
  ArrayOrders : BlockOrdersArray;
 ArrayPos    : BlockArraysPos;
  PosReward   : int64;
  PosCount    : integer;
  CounterPos  : integer;
Begin
SetCurrentJob('RebuildSumario',true);
EnterCriticalSection(CSSumary);
RebuildingSumary := true;
SetLength(ListaSumario,0);
// incluir el pago del bloque genesys
UpdateSumario(ADMINHash,PremineAmount,0,'0');
for contador := 1 to UntilBlock do
   begin
   if contador mod 10 = 0 then
      begin
      info(LangLine(130)+inttoStr(contador));  //'Rebuilding sumary block: '
      EngineLastUpdate := UTCTime.ToInt64;
      application.ProcessMessages;
      end;
   BlockHeader := Default(BlockHeaderData);
   BlockHeader := LoadBlockDataHeader(contador);
   UpdateSumario(BlockHeader.AccountMiner,BlockHeader.Reward+BlockHeader.MinerFee,0,IntToStr(contador));
   ArrayOrders := Default(BlockOrdersArray);
   ArrayOrders := GetBlockTrxs(contador);
   for cont := 0 to length(ArrayOrders)-1 do
      begin
      if ArrayOrders[cont].OrderType='CUSTOM' then
         begin
         UpdateSumario(ArrayOrders[cont].Sender,Restar(Customizationfee),0,IntToStr(contador));
         setcustomalias(ArrayOrders[cont].Sender,ArrayOrders[cont].Receiver,contador);
         end;
      if ArrayOrders[cont].OrderType='TRFR' then
         begin
         UpdateSumario(ArrayOrders[cont].Sender,Restar(ArrayOrders[cont].AmmountFee+ArrayOrders[cont].AmmountTrf),0,IntToStr(contador));
         UpdateSumario(ArrayOrders[cont].Receiver,ArrayOrders[cont].AmmountTrf,0,IntToStr(contador));
         end;
      end;
   setlength(ArrayOrders,0);
   if contador >= PoSBlockStart then
      begin
      ArrayPos := GetBlockPoSes(contador);
      PosReward := StrToIntDef(Arraypos[length(Arraypos)-1].address,0);
      SetLength(ArrayPos,length(ArrayPos)-1);
      PosCount := length(ArrayPos);
      for counterpos := 0 to PosCount-1 do
         UpdateSumario(ArrayPos[counterPos].address,Posreward,0,IntToStr(contador));
      // Restar el PoS al minero
      UpdateSumario(BlockHeader.AccountMiner,Restar(PosCount*Posreward),0,IntToStr(contador));
      SetLength(ArrayPos,0);
      end;
   end;
ListaSumario[0].LastOP:=contador;
RebuildingSumary := false;
LeaveCriticalSection(CSSumary);
GuardarSumario();
UpdateMyData();
SetCurrentJob('RebuildSumario',true);
ConsoleLinesAdd(LangLine(131));  //'Sumary rebuilded.'
end;

// adds a header at the end of headers file
Procedure AddBlchHead(Numero: int64; hash,sumhash:string);
var
  Dato: ResumenData;
Begin
EnterCriticalSection(CSHeadAccess);
   try
   assignfile(FileResumen,ResumenFilename);
   reset(FileResumen);
   Dato := Default(ResumenData);
   Dato.block:=Numero;
   Dato.blockhash:=hash;
   Dato.SumHash:=sumhash;
   seek(fileResumen,filesize(fileResumen));
   write(fileResumen,dato);
   closefile(FileResumen);
   Except on E:Exception do
      tolog ('Error adding new register to headers');
   end;
LeaveCriticalSection(CSHeadAccess);
End;

// Deletes last header from headers file
Procedure DelBlChHeadLast();
Begin
EnterCriticalSection(CSHeadAccess);
   try
   assignfile(FileResumen,ResumenFilename);
   reset(FileResumen);
   seek(fileResumen,filesize(fileResumen)-1);
   truncate(fileResumen);
   closefile(FileResumen);
   Except on E:Exception do
      tolog ('Error deleting last record from headers');
   end;
LeaveCriticalSection(CSHeadAccess);
End;

// Creates user transactions file
Procedure CrearMistrx();
var
  DefaultOrder : MyTrxData;
Begin
   try
   DefaultOrder := Default(MyTrxData);
   DefaultOrder.Block:=0;
   DefaultOrder.receiver:='0 0';
   assignfile(FileMyTrx,MyTrxFilename);
   rewrite(FileMyTrx);
   write(FileMyTrx,DefaultOrder);
   closefile(FileMyTrx);
   SetLength(ListaMisTrx,1);
   ListaMisTrx[0] := DefaultOrder;
   Except on E:Exception do
      toexclog ('Error creating my trx file: '+E.Message);
   end;
End;

// Loads user transactions from disk
Procedure CargarMisTrx();
var
  dato : MyTrxData;
Begin
   try
   assignfile(FileMyTrx,MyTrxFilename);
   reset(FileMyTrx);
   setlength(ListaMisTrx,0);
   while not eof(FileMyTrx) do
      begin
      Dato := Default(MyTrxData);
      setlength(ListaMisTrx,length(ListaMisTrx)+1);
      read(FileMyTrx,dato);
      ListaMisTrx[length(ListaMisTrx)-1] := dato;
      end;
   closefile(FileMyTrx);
   G_PoSPayouts := StrToInt64Def(parameter(ListaMisTrx[0].receiver,0),0);
   G_PoSEarnings := StrToInt64Def(parameter(ListaMisTrx[0].receiver,1),0);
   Except on E:Exception do
      toexclog ('Error loading my trx from file');
   end;
End;

// Save value of last checked block for user transactions
Procedure SaveMyTrxsLastUpdatedblock(Number:integer;PoSPayouts, PoSEarnings:int64);
var
  FirstTrx : MyTrxData;
Begin
   try
   FirstTrx := Default(MyTrxData);
   FirstTrx.block:=Number;
   FirstTrx.receiver := IntToStr(PoSPayouts)+' '+IntToStr(PoSEarnings);
   assignfile (FileMyTrx,MyTrxFilename);
   reset(FileMyTrx);
   seek(FileMyTrx,0);
   write(FileMyTrx,FirstTrx);
   Closefile(FileMyTrx);
   G_PoSPayouts  := PoSPayouts;
   G_PoSEarnings := PoSEarnings;
   ListaMisTrx[0].receiver := IntToStr(PoSPayouts)+' '+IntToStr(PoSEarnings);
   if G_PoSPayouts > 0 then
      ToLog(Format('Total PoS : %d : %s',[G_PoSPayouts,Int2curr(G_PoSEarnings)]));
   Except on E:Exception do
      toExclog ('Error setting last block checked for my trx');
   end;
End;

// Rebuilds user transactions  file up to specified block
Procedure RebuildMyTrx(blocknumber:integer);
var
  contador,contador2 : integer;
  Existentes : integer;
  Header : BlockHeaderData;
  NewTrx : MyTrxData;
  ArrTrxs : BlockOrdersArray;

  ArrayPos    : BlockArraysPos;
  PosReward   : int64;
  PosCount    : integer;
  CounterPos  : integer;
  PoSPayouts, PoSEarnings : int64;
  BlockPayouts, BlockEarnings : int64;
Begin
Existentes := Length(ListaMisTrx);
if ListaMisTrx[0].Block < blocknumber then
   begin
   PoSPayouts := StrToInt64Def(parameter(ListaMisTrx[0].receiver,0),0);
   PoSEarnings := StrToInt64Def(parameter(ListaMisTrx[0].receiver,1),0);
   for contador := ListaMisTrx[0].Block+1 to blocknumber do
      begin
      if Not G_Launching then
         begin
         info(Format('Rebuilding my Trxs: %d',[contador]));
         EngineLastUpdate := UTCTime.ToInt64;
         application.ProcessMessages;
         end;
      BlockPayouts := 0; BlockEarnings := 0;
      Header := LoadBlockDataHeader(contador);
      if DireccionEsMia(Header.AccountMiner)>=0 then // user is miner
         begin
         NewTrx := Default(MyTrxData);
         NewTrx.block:=contador;
         NewTrx.time :=header.TimeEnd;
         NewTrx.tipo :='MINE';
         NewTrx.receiver:=header.AccountMiner;
         NewTrx.monto   :=header.Reward+header.MinerFee;
         NewTrx.trfrID  :='';
         NewTrx.OrderID :='';
         NewTrx.reference:='';
         insert(NewTrx,ListaMisTrx,length(ListaMisTrx));
         end;
      ArrTrxs := GetBlockTrxs(contador);
      if length(ArrTrxs)>0 then
         begin
         for contador2 := 0 to length(ArrTrxs)-1 do
            begin
            if DireccionEsMia(ArrTrxs[contador2].sender)>=0 then // user is sender
               begin
               NewTrx := Default(MyTrxData);
               NewTrx.block:=contador;
               NewTrx.time :=header.TimeEnd;
               NewTrx.tipo :=ArrTrxs[contador2].OrderType;
               NewTrx.receiver:= ArrTrxs[contador2].Receiver;
               NewTrx.monto   := Restar(ArrTrxs[contador2].AmmountFee+ArrTrxs[contador2].AmmountTrf);
               NewTrx.trfrID  := ArrTrxs[contador2].TrfrID;
               NewTrx.OrderID := ArrTrxs[contador2].OrderID;
               NewTrx.reference:= ArrTrxs[contador2].reference;
               insert(NewTrx,ListaMisTrx,length(ListaMisTrx));
               end;
            if DireccionEsMia(ArrTrxs[contador2].receiver)>=0 then //user is receiver
               begin
               NewTrx := Default(MyTrxData);
               NewTrx.block:=contador;
               NewTrx.time :=header.TimeEnd;
               NewTrx.tipo :=ArrTrxs[contador2].OrderType;
               NewTrx.receiver:= ArrTrxs[contador2].receiver;
               NewTrx.monto   := ArrTrxs[contador2].AmmountTrf;
               NewTrx.trfrID  := ArrTrxs[contador2].TrfrID;
               NewTrx.OrderID := ArrTrxs[contador2].OrderID;
               NewTrx.reference:= ArrTrxs[contador2].reference;
               insert(NewTrx,ListaMisTrx,length(ListaMisTrx));
               end;
            end;
         end;
      setlength(ArrTrxs,0);
      if contador >= PoSBlockStart then
         begin
         ArrayPos := GetBlockPoSes(contador);
         PosReward := StrToIntDef(Arraypos[length(Arraypos)-1].address,0);
         SetLength(ArrayPos,length(ArrayPos)-1);
         PosCount := length(ArrayPos);
         for counterpos := 0 to PosCount-1 do
            begin
            if direccionesmia(ArrayPos[counterPos].address)>=0 then
               begin
               BlockPayouts+=1;
               PoSPayouts := PoSPayouts+1;
               BlockEarnings := BlockEarnings+PosReward;
               PoSEarnings := PoSEarnings + PosReward;
               end;
            end;
         if BlockPayouts > 0 then
            ToLog(Format('PoS : %d -> %d : %s',[contador,BlockPayouts,Int2curr(BlockEarnings)]));
         SetLength(ArrayPos,0);
         end;
      end;
   ListaMisTrx[0].block:=blocknumber;
   ListaMisTrx[0].receiver:=IntToStr(PoSPayouts)+' '+IntToStr(PoSEarnings);
   if length(ListaMisTrx) > Existentes then  // se han añadido transacciones
      begin
      SaveMyTrxsToDisk(existentes);
      U_Mytrxs := true;
      end;
   SaveMyTrxsLastUpdatedblock(blocknumber, PoSPayouts, PoSEarnings);
   end;
End;

// Save last user transactions to disk
Procedure SaveMyTrxsToDisk(Cantidad:integer);
var
  contador : integer;
Begin
   try
   assignfile (FileMyTrx,MyTrxFilename);
   reset(FileMyTrx);
   for contador := cantidad to length(ListaMisTrx)-1 do
      begin
      seek(FileMyTrx,contador);
      write(FileMyTrx,ListaMisTrx[contador]);
      end;
   Closefile(FileMyTrx);
   Except on E:Exception do
      tolog ('Error saving my trx to disk');
   end;
End;

// Non blocking rebuilding user transactions
Function NewMyTrx(aParam:Pointer):PtrInt;
Begin
CrearMistrx();
CargarMisTrx();
RebuildMyTrx(MyLastBlock);
ConsoleLinesAdd('My transactions rebuilded');
NewMyTrx := -1;
End;

// Creates a bat file for restart
Procedure CrearBatFileForRestart();
var
  archivo : textfile;
Begin
try
  Assignfile(archivo, 'nosolauncher.bat');
  rewrite(archivo);
  writeln(archivo,'echo Restarting Noso...');
  writeln(archivo,'TIMEOUT 5');
  writeln(archivo,'start '+Application.ExeName);
  Closefile(archivo);
  Except on E:Exception do
    tolog ('Error creating restart file');
  end;
end;

// Prepares for restart
Procedure RestartNoso();
Begin
CrearBatFileForRestart();
RunExternalProgram('nosolauncher.bat');
End;

// Runs doctor tool
Procedure RunDiagnostico(linea:string);
var
  cont : integer;
  lastblock : integer;
  dato : ResumenData;
  fixfiles: boolean = false;
  errores : integer = 0;
  fixed : integer = 0;
  porcentaje : integer;
Begin
Miner_KillThreads := true;
CloseAllforms();
CerrarClientes();
StopServer();
StopPoolServer();
If Miner_IsOn then Miner_IsON := false;
KillAllMiningThreads;
setlength(CriptoOpsTipo,0);
RunningDoctor := true;
if UpperCase(parameter(linea,1)) = 'FIX' then fixfiles := true;
lastblock := GetMyLastUpdatedBlock;
forminicio.Caption:='Noso Doctor';
GridInicio.RowCount:=0;
FormInicio.BorderIcons:=FormInicio.BorderIcons-[bisystemmenu];
forminicio.visible := true;
form1.Visible:=false;
if lastblock = 0 then
   begin
   outtext('You can not run diagnostic now',false,1);
   RunningDoctor := false;
   FormInicio.BorderIcons:=FormInicio.BorderIcons+[bisystemmenu];
   exit;
   end;
outtext('Blocks to check: '+IntToStr(lastblock+1),false,1);
outtext('Checking block files 0 %',false,1);
for cont := 0 to lastblock do
   begin
   gridinicio.RowCount := gridinicio.RowCount-1;
   if not fileexists(BlockDirectory+IntToStr(cont)+'.blk') then
      begin
      errores +=1;
      end;
   porcentaje := (cont * 100) div lastblock;
   outtext('Checking block files '+inttostr(porcentaje)+' %',false,1);
   end;
outtext('Block hash correct 0 %',false,1);
assignfile(FileResumen,ResumenFilename);
reset(FileResumen);
for cont := 0 to lastblock do
   begin
   Seek(FileResumen,cont);
   Read(FileResumen,dato);
   gridinicio.RowCount := gridinicio.RowCount-1;
   if HashMD5File(BlockDirectory+IntToStr(cont)+'.blk')<> dato.blockhash then
      begin
      errores +=1;
      if fixfiles then
         begin
         fixed +=1;
         dato.block:=cont;
         dato.blockhash:=HashMD5File(BlockDirectory+IntToStr(cont)+'.blk');
         Seek(FileResumen,cont);
         write(FileResumen,dato);
         end;
      end;
   porcentaje := (cont * 100) div lastblock;
   outtext('Block hash correct '+inttostr(porcentaje)+' %',false,1);
   end;
outtext('Sumary hash correct 0 %',false,1);
for cont := 1 to lastblock do
   begin
   Seek(FileResumen,cont);
   Read(FileResumen,dato);
   gridinicio.RowCount := gridinicio.RowCount-1;
   if cont = 1 then RebuildSumario(cont)
   else AddBlockToSumary(cont);
   if HashMD5File(SumarioFilename) <> dato.SumHash then
      begin
      errores +=1;
      if fixfiles then
         begin
         fixed +=1;
         dato.block:=cont;
         dato.SumHash:=HashMD5File(SumarioFilename);
         Seek(FileResumen,cont);
         write(FileResumen,dato);
         end
      end;
   porcentaje := (cont * 100) div lastblock;
   outtext('Sumary hash correct '+IntToStr(porcentaje)+' %',false,1);
   end;
closefile(FileResumen);
outtext('Errors: '+IntToStr(errores)+' / Fixed: '+IntToStr(fixed),false,1);
RunningDoctor := false;
FormInicio.BorderIcons:=FormInicio.BorderIcons+[bisystemmenu];
UpdateMyData();
End;

// Creates the pool info file
Procedure CrearArchivoPoolInfo(nombre,direccion:string;porcentaje,miembros,port,tipo:integer;pass:string);
var
  dato : PoolInfoData;
Begin
assignfile(FilePool,PoolInfoFilename);
rewrite(FilePool);
dato.Name := nombre;
dato.Direccion:=direccion;
dato.Porcentaje:=porcentaje;
dato.MaxMembers:=miembros;
dato.Port:=port;
dato.TipoPago:=tipo;
Dato.FeeEarned:=0;
dato.PassWord:=pass;
write(filepool,dato);
Closefile(FilePool);
PoolInfo := Dato;
ResetPoolMiningInfo;
End;

// Saves the pool info file
Procedure GuardarArchivoPoolInfo();
Begin
setmilitime('GuardarArchivoPoolInfo',1);
   try
   assignfile(FilePool,PoolInfoFilename);
   rewrite(FilePool);
   write(filepool,PoolInfo);
   Closefile(FilePool);
   Except on E:Exception do
      tolog('Error saving PoolInfo file:'+E.Message);
   end;
S_PoolInfo := false;
setmilitime('GuardarArchivoPoolInfo',2);
End;

// Reads pool info from file
function GetPoolInfoFromDisk():PoolInfoData;
var
  dato : PoolInfoData;
Begin
try
assignfile(FilePool,PoolInfoFilename);
reset(FilePool);
read(filepool,dato);
result := dato;
Closefile(FilePool);
PoolInfo := Dato;
Except on E:Exception do
  tolog('Error loading pool info from disk');
end;
End;

// Creates pool members file
Procedure CrearArchivoPoolMembers;
Begin
assignfile(FilePoolMembers,PoolMembersFilename);
rewrite(FilePoolMembers);
Closefile(FilePoolMembers);
End;

// Load poolmembers file from disk
Procedure LoadPoolMembers();
var
  contador : integer;
  dato : PoolMembersData;
Begin
// ADD A VERIFICATION BEFORE LOAD IT IN CASE THE FILE IS CORRUPTED?
TRY
   assignfile(FilePoolMembers,PoolMembersFilename);
   reset(FilePoolMembers);
   setlength(ArrayPoolMembers,filesize(FilePoolMembers));
   if filesize(FilePoolMembers) > 0 then
      begin
      for contador := 0 to filesize(FilePoolMembers)-1 do
         begin
         seek(FilePoolMembers,contador);
         read(FilePoolMembers,dato);
         ArrayPoolMembers[contador]:= dato;
         end;
      end;
   Closefile(FilePoolMembers);
EXCEPT on E:Exception do
   ToLog('Error loading pool members from disk.');
END;
End;

// Save pool members file to disk
Procedure GuardarPoolMembers();
var
  contador : integer;
  SavedOk : boolean = false;
  CopyArray :array of PoolMembersData;
Begin
setmilitime('GuardarPoolMembers',1);
assignfile(FilePoolMembers,PoolMembersFilename);
   TRY
   reset(FilePoolMembers);
   setlength(CopyArray,0);
   EnterCriticalSection(CSPoolMembers);
   CopyArray := copy(ArrayPoolMembers,0,length(ArrayPoolMembers));
   LeaveCriticalSection(CSPoolMembers);
   for contador := 0 to length(CopyArray)-1 do
      begin
      seek(FilePoolMembers,contador);
      write(FilePoolMembers,CopyArray[contador]);
      end;
   Closefile(FilePoolMembers);
   //truncate(FilePoolMembers);
   SavedOk := true;
   EXCEPT on E:Exception do
      ToExcLog('Error saving pool members to disk: '+E.Message);
   END;
SetLength(CopyArray,0);
if SavedOk then S_PoolMembers := false;
setmilitime('GuardarPoolMembers',2);
End;

// Creates and executes autolauncher.bat
Procedure EjecutarAutoUpdate(version:string);
var
  archivo : textfile;
Begin
try
  Assignfile(archivo, 'nosolauncher.bat');
  rewrite(archivo);
  writeln(archivo,'echo Restarting Noso...');
  writeln(archivo,'TIMEOUT 5');
  writeln(archivo,'del noso.exe');
  writeln(archivo,'ren noso'+version+'.exe noso.exe');
  writeln(archivo,'start noso.exe');
  Closefile(archivo);
Except on E:Exception do
   tolog ('Error creating restart file');
end;
RunExternalProgram('nosolauncher.bat');
End;

// Creates autorestart file
Procedure CrearRestartfile();
var
  archivo : textfile;
Begin
Assignfile(archivo, 'restart.txt');
   try
   rewrite(archivo);
   writeln(archivo,GetCurrentStatus(0));
   Closefile(archivo);
   Except on E:Exception do
      tolog ('Error creating restart file');
   end;
End;

// apply restart conditions
Procedure RestartConditions();
var
  archivo : textfile;
  linea : string;
  Server,connect : boolean;
Begin
Assignfile(archivo, 'restart.txt');
reset(archivo);
ReadLn(archivo,linea);
ReadLn(archivo,Miner_RestartedSolution);
Closefile(archivo);
server := StrToBool(parameter(linea,1));
connect := StrToBool(parameter(linea,3));
if server then ProcessLinesAdd('SERVERON');
if connect then ProcessLinesAdd('CONNECT');
tryDeletefile('restart.txt');
End;

// Creates crashinfofile
Procedure CrearCrashInfo();
var
  archivo : textfile;
Begin
Assignfile(archivo, 'crashinfo.txt');
   try
   if not fileexists('crashinfo.txt') then rewrite(archivo)
   else append(archivo);
   writeln(archivo,GetCurrentStatus(1));
   {
   while ExceptLines.Count>0 do
      begin
      Writeln(archivo, ExceptLines[0]);
      ExceptLines.Delete(0);
      end;
   }
   Closefile(archivo);
   Except on E:Exception do
      tolog ('Error creating crashinfo file');
   end;
End;

// Gets OS version
function OSVersion: string;
begin
  {$IFDEF LCLcarbon}
  OSVersion := 'Mac OS X 10.';
  {$ELSE}
  {$IFDEF Linux}
  OSVersion := 'Linux Kernel ';
  {$ELSE}
  {$IFDEF UNIX}
  OSVersion := 'Unix ';
  {$ELSE}
  {$IFDEF WINDOWS}
  OSVersion:= GetWinVer;
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

// Returns the windows version
{$IFDEF WINDOWS}
Function GetWinVer():string;
Begin
if WindowsVersion = wv95 then result := 'Windows95'
  else if WindowsVersion = wvNT4 then result := 'WindowsNTv.4'
  else if WindowsVersion = wv98 then result := 'Windows98'
  else if WindowsVersion = wvMe then result := 'WindowsME'
  else if WindowsVersion = wv2000 then result := 'Windows2000'
  else if WindowsVersion = wvXP then result := 'WindowsXP'
  else if WindowsVersion = wvServer2003 then result := 'WindowsServer2003/WindowsXP64'
  else if WindowsVersion = wvVista then result := 'WindowsVista'
  else if WindowsVersion = wv7 then result := 'Windows7'
  else if WindowsVersion = wv10 then result := 'Windows10'
  else result := 'WindowsUnknown';
End;
{$ENDIF}

// Executes the required steps to restore the blockchain
Procedure RestoreBlockChain();
Begin
Miner_KillThreads := true;
CloseAllforms();
CerrarClientes();
StopServer();
StopPoolServer();
If Miner_IsOn then Miner_IsON := false;
KillAllMiningThreads;
setlength(CriptoOpsTipo,0);
deletefile(SumarioFilename);
deletefile(SumarioFilename+'.bak');
deletefile(ResumenFilename);
deletefile(MyTrxFilename);
if DeleteDirectory(BlockDirectory,True) then
   RemoveDir(BlockDirectory);
ProcessLinesAdd('restart');
End;

Procedure InitCrossValues();
Begin
OptionsFileName     := 'NOSODATA'+DirectorySeparator+'options.psk';
BotDataFilename     := 'NOSODATA'+DirectorySeparator+'botdata.psk';
NodeDataFilename    := 'NOSODATA'+DirectorySeparator+'nodes.psk';
NTPDataFilename     := 'NOSODATA'+DirectorySeparator+'ntpservers.psk';
WalletFilename      := 'NOSODATA'+DirectorySeparator+'wallet.pkw';
SumarioFilename     := 'NOSODATA'+DirectorySeparator+'sumary.psk';
LanguageFileName    := 'NOSODATA'+DirectorySeparator+'noso.lng';
BlockDirectory      := 'NOSODATA'+DirectorySeparator+'BLOCKS'+DirectorySeparator;
UpdatesDirectory    := 'NOSODATA'+DirectorySeparator+'UPDATES'+DirectorySeparator;
LogsDirectory       := 'NOSODATA'+DirectorySeparator+'LOGS'+DirectorySeparator;
ExceptLogFilename   := 'NOSODATA'+DirectorySeparator+'LOGS'+DirectorySeparator+'exceptlog.txt';
ResumenFilename     := 'NOSODATA'+DirectorySeparator+'blchhead.nos';
MyTrxFilename       := 'NOSODATA'+DirectorySeparator+'mytrx.nos';
TranslationFilename := 'NOSODATA'+DirectorySeparator+'English_empty.txt';
ErrorLogFilename    := 'NOSODATA'+DirectorySeparator+'errorlog.txt';
PoolInfoFilename    := 'NOSODATA'+DirectorySeparator+'poolinfo.dat';
PoolMembersFilename := 'NOSODATA'+DirectorySeparator+'poolmembers.dat';
AdvOptionsFilename  := 'NOSODATA'+DirectorySeparator+'advopt.txt';
PoolPaymentsFilename:= 'NOSODATA'+DirectorySeparator+'poolpays.txt';
End;

// Try to delete a file safely
function TryDeleteFile(filename:string):boolean;
Begin
result := true;
   try
   deletefile(filename);
   Except on E:Exception do
      begin
      result := false;
      ToExcLog('Error deleting file ('+filename+') :'+E.Message);
      end;
   end;
End;

END. // END UNIT

