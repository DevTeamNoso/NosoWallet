unit mpProtocol;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, mpRed, MasterPaskalForm, mpParser, StrUtils, mpDisk, mpTime,mpMiner, mpBlock,
  Zipper, mpcoin, mpCripto;

function GetPTCEcn():String;
Function GetOrderFromString(textLine:String):OrderData;
function GetStringFromOrder(order:orderdata):String;
function GetStringFromBlockHeader(blockheader:BlockHeaderdata):String;
Function ProtocolLine(tipo:integer):String;
Procedure ParseProtocolLines();
function IsValidProtocol(line:String):Boolean;
Procedure PTC_Getnodes(Slot:integer);
function GetNodesString():string;
Procedure PTC_SendLine(Slot:int64;Message:String);
Procedure PTC_SaveNodes(LineText:String);
function GetNodeFromString(NodeDataString: string): NodeData;
Procedure ProcessPing(LineaDeTexto: string; Slot: integer; Responder:boolean);
function GetPingString():string;
Procedure SendMesjsSalientes();
procedure PTC_SendPending(Slot:int64);
Procedure PTC_Newblock(Texto:String);
Procedure PTC_SendResumen(Slot:int64);
Procedure PTC_SendBlocks(Slot:integer;TextLine:String);
Procedure INC_PTC_Custom(TextLine:String);
Procedure PTC_Custom(TextLine:String);
function ValidateTrfr(order:orderdata;Origen:String):Boolean;
Procedure INC_PTC_Order(TextLine:String);
Procedure PTC_Order(TextLine:String);

CONST
  Getnodes = 1;
  Nodes = 2;
  Ping = 3;
  Pong = 4;
  GetPending = 5;
  NewBlock = 6;
  GetResumen = 7;
  LastBlock = 8;
  Custom = 9;

implementation

uses
  mpGui;

// Devuelve el puro encabezado con espacio en blanco al final
function GetPTCEcn():String;
Begin
result := 'PSK '+IntToStr(protocolo)+' '+ProgramVersion+' '+UTCTime+' ';
End;

// convierte los datos de la cadena en una order
Function GetOrderFromString(textLine:String):OrderData;
var
  orderinfo : OrderData;
Begin
OrderInfo := Default(OrderData);
OrderInfo.OrderID    := Parameter(textline,1);
OrderInfo.OrderLines := StrToInt(Parameter(textline,2));
OrderInfo.OrderType  := Parameter(textline,3);
OrderInfo.TimeStamp  := StrToInt64(Parameter(textline,4));
OrderInfo.Concept    := Parameter(textline,5);
OrderInfo.TrxLine    := StrToInt(Parameter(textline,6));
OrderInfo.Sender     := Parameter(textline,7);
OrderInfo.Receiver   := Parameter(textline,8);
OrderInfo.AmmountFee := StrToInt64(Parameter(textline,9));
OrderInfo.AmmountTrf := StrToInt64(Parameter(textline,10));
OrderInfo.Signature  := Parameter(textline,11);
OrderInfo.TrfrID     := Parameter(textline,12);
Result := OrderInfo;
End;

// Convierte una orden en una cadena para compartir
function GetStringFromOrder(order:orderdata):String;
Begin
result:= Order.OrderType+' '+
         Order.OrderID+' '+
         IntToStr(order.OrderLines)+' '+
         order.OrderType+' '+
         IntToStr(Order.TimeStamp)+' '+
         Order.Concept+' '+
         IntToStr(order.TrxLine)+' '+
         order.Sender+' '+
         Order.Receiver+' '+
         IntToStr(Order.AmmountFee)+' '+
         IntToStr(Order.AmmountTrf)+' '+
         Order.Signature+' '+
         Order.TrfrID;
End;

// devuelve una cadena con los datos de la cabecera de un bloque
function GetStringFromBlockHeader(BlockHeader:blockheaderdata):String;
Begin
result := 'Number:'+IntToStr(BlockHeader.Number)+' '+
          'Start:' +IntToStr(BlockHeader.TimeStart)+' '+
          'End:'+IntToStr(BlockHeader.TimeEnd)+' '+
          'Total:'+IntToStr(BlockHeader.TimeTotal)+' '+
          '20:'+IntToStr(BlockHeader.TimeLast20)+' '+
          'Trxs:'+IntToStr(BlockHeader.TrxTotales)+' '+
          'Diff:'+IntToStr(BlockHeader.Difficult)+' '+
          'Target:'+BlockHeader.TargetHash+' '+
          'Solution:'+BlockHeader.Solution+' '+
          'NextDiff:'+IntToStr(BlockHeader.NxtBlkDiff)+' '+
          'Miner:'+BlockHeader.AccountMiner+' '+
          'Fee:'+IntToStr(BlockHeader.MinerFee)+' '+
          'Reward:'+IntToStr(BlockHeader.Reward);

End;

//Devuelve la linea de protocolo solicitada
Function ProtocolLine(tipo:integer):String;
var
  Resultado : String = '';
  Encabezado : String = '';
Begin
Encabezado := 'PSK '+IntToStr(protocolo)+' '+ProgramVersion+' '+UTCTime+' ';
if tipo = GetNodes then
   Resultado := '$GETNODES';
if tipo = Nodes then
   Resultado := '$NODES'+GetNodesString();
if tipo = Ping then
   Resultado := '$PING '+GetPingString;
if tipo = Pong then
   Resultado := '$PONG '+GetPingString;
if tipo = GetPending then
   Resultado := '$GETPENDING';
if tipo = NewBlock then
   Resultado := '$NEWBL ';
if tipo = GetResumen then
   Resultado := '$GETRESUMEN';
if tipo = LastBlock then
   Resultado := '$LASTBLOCK '+IntToStr(mylastblock);
if tipo = Custom then
   Resultado := '$CUSTOM ';
Resultado := Encabezado+Resultado;
Result := resultado;
End;

// Procesa todas las lineas procedentes de las conexiones
Procedure ParseProtocolLines();
var
  contador : integer = 0;
  UsedProtocol : integer = 0;
  UsedVersion : string = '';
  PeerTime: String = '';
  Linecomando : string = '';
Begin
for contador := 1 to MaxConecciones do
   begin
   While SlotLines[contador].Count > 0 do
      begin
      UsedProtocol := StrToInt(Parameter(SlotLines[contador][0],1));
      UsedVersion := Parameter(SlotLines[contador][0],2);
      PeerTime := Parameter(SlotLines[contador][0],3);
      LineComando := Parameter(SlotLines[contador][0],4);
      if ((not IsValidProtocol(SlotLines[contador][0])) and (not Conexiones[contador].Autentic)) then
         // La linea no es valida y proviene de una conexion no autentificada
         begin
         ConsoleLines.Add(LangLine(22)+conexiones[contador].ip); //CONNECTION REJECTED: INVALID PROTOCOL ->
         UpdateBotData(conexiones[contador].ip);
         CerrarSlot(contador);
         end;
      if UpperCase(LineComando) = '$GETNODES' then PTC_Getnodes(contador)
      else if UpperCase(LineComando) = '$NODES' then PTC_SaveNodes(SlotLines[contador][0])
      else if UpperCase(LineComando) = '$PING' then ProcessPing(SlotLines[contador][0],contador,true)
      else if UpperCase(LineComando) = '$PONG' then ProcessPing(SlotLines[contador][0],contador,false)
      else if UpperCase(LineComando) = '$GETPENDING' then PTC_SendPending(contador)
      else if UpperCase(LineComando) = '$NEWBL' then PTC_NewBlock(SlotLines[contador][0])
      else if UpperCase(LineComando) = '$GETRESUMEN' then PTC_SendResumen(contador)
      else if UpperCase(LineComando) = '$LASTBLOCK' then PTC_SendBlocks(contador,SlotLines[contador][0])
      else if UpperCase(LineComando) = '$CUSTOM' then INC_PTC_Custom(GetOpData(SlotLines[contador][0]))
      else if UpperCase(LineComando) = 'ORDER' then INC_PTC_Order(SlotLines[contador][0])
      else
         Begin  // El comando recibido no se reconoce. Verificar protocolos posteriores.
         ConsoleLines.Add(LangLine(23)+SlotLines[contador][0]+') '+intToStr(contador)); //Unknown command () in slot: (
         end;
      if SlotLines[contador].count > 0 then SlotLines[contador].Delete(0);
      end;
   end;
End;

// Verifica si una linea recibida en una conexion es una linea valida de protocolo
function IsValidProtocol(line:String):Boolean;
Begin
if copy(line,1,4) = 'PSK ' then result := true
else result := false;
End;

// Procesa una solicitud de nodos
Procedure PTC_Getnodes(Slot:integer);
Begin
PTC_SendLine(slot,ProtocolLine(Nodes));
End;

// Devuelve una cadena con la info de los 50 primeros nodos validos.
function GetNodesString():string;
var
  NodesString : String = '';
  NodesAdded : integer = 0;
  Counter : integer;
Begin
for counter := 0 to length(ListaNodos)-1 do
   begin
   NodesString := NodesString+' '+ListaNodos[counter].ip+':'+ListaNodos[counter].port+':'
   +ListaNodos[counter].LastConexion+':';
   NodesAdded := NodesAdded+1;
   if NodesAdded>50 then break;
   end;
result := NodesString;
End;

// Envia una linea a un determinado slot
Procedure PTC_SendLine(Slot:int64;Message:String);
Begin
if conexiones[Slot].tipo='CLI' then
   begin
      try
      Conexiones[Slot].context.Connection.IOHandler.WriteLn(Message);
      except
      On E :Exception do
         begin
         ConsoleLines.Add(E.Message);
         CerrarSlot(Slot);
         end;
      end;
   end;
if conexiones[Slot].tipo='SER' then
   begin
      try
      CanalCliente[Slot].IOHandler.WriteLn(Message);
      except
      On E :Exception do
         begin
         ConsoleLines.Add(E.Message);
         CerrarSlot(Slot);
         end;
      end;
   end;
end;

// Guarda los nodos recibidos desde otro usuario
Procedure PTC_SaveNodes(LineText:String);
var
  NodosList : TStringList;
  Contador : integer = 5;
  MoreParam : boolean = true;
  ThisParam : String = '';
  ThisNode : NodeData;
Begin
NodosList := TStringList.Create;
while MoreParam do
   begin
   ThisParam := Parameter(LineText,contador);
   if thisparam = '' then MoreParam := false
   else NodosList.Add(ThisParam);
   contador := contador+1;
   end;
for contador := 0 to NodosList.Count-1 do
   Begin
   ThisParam := StringReplace(NodosList[contador],':',' ', [rfReplaceAll, rfIgnoreCase]);
   ThisNode := GetNodeFromString(ThisParam);
   If NodeExists(ThisNode.ip,ThisNode.port)<0 then
      UpdateNodeData(ThisNode.ip,ThisNode.port,ThisNode.LastConexion);
   end;
NodosList.Free;
End;

// Devuelve la info de un nodo a partir de una cadena pre-tratada
function GetNodeFromString(NodeDataString: string): NodeData;
var
  Resultado : NodeData;
Begin
Resultado.ip:= GetCommand(NodeDataString);
Resultado.port:=Parameter(NodeDataString,1);
Resultado.LastConexion:=Parameter(NodeDataString,2);
Result := Resultado;
End;

// Procesa un ping recibido y envia el PONG si corresponde.
Procedure ProcessPing(LineaDeTexto: string; Slot: integer; Responder:boolean);
var
  PProtocol, PVersion, PConexiones, PTime, PLastBlock, PLastBlockHash, PSumHash, PPending : string;
  PResumenHash, PConStatus, PListenPort : String;
Begin
PProtocol      := Parameter(LineaDeTexto,1);
PVersion       := Parameter(LineaDeTexto,2);
PTime          := Parameter(LineaDeTexto,3);
PConexiones    := Parameter(LineaDeTexto,5);
PLastBlock     := Parameter(LineaDeTexto,6);
PLastBlockHash := Parameter(LineaDeTexto,7);
PSumHash       := Parameter(LineaDeTexto,8);
PPending       := Parameter(LineaDeTexto,9);
PResumenHash   := Parameter(LineaDeTexto,10);
PConStatus     := Parameter(LineaDeTexto,11);
PListenPort    := Parameter(LineaDeTexto,12);
conexiones[slot].Autentic:=true;
conexiones[slot].Connections:=StrToIntDef(PConexiones,1);
conexiones[slot].Version:=PVersion;
conexiones[slot].Lastblock:=PLastBlock;
conexiones[slot].LastblockHash:=PLastBlockHash;
conexiones[slot].SumarioHash:=PSumHash;
conexiones[slot].Pending:=StrToIntDef(PPending,0);
conexiones[slot].Protocol:=StrToIntDef(PProtocol,0);
conexiones[slot].offset:=StrToInt64(PTime)-StrToInt64(UTCTime);
conexiones[slot].lastping:=UTCTime;
conexiones[slot].ResumenHash:=PResumenHash;
conexiones[slot].ConexStatus:=StrToInt(PConStatus);
conexiones[slot].ListeningPort:=StrToIntDef(PListenPort,-1);
if responder then PTC_SendLine(slot,ProtocolLine(4));
if responder then G_TotalPings := G_TotalPings+1;
End;

// Devuelve la informacion contenida en un ping
function GetPingString():string;
var
  Port : integer = 0;
Begin
if Form1.Server.Active then port := UserOptions.Port else port:= -1 ;
result :=IntToStr(GetTotalConexiones())+' '+
         IntToStr(MyLastBlock)+' '+
         MyLastBlockHash+' '+
         MySumarioHash+' '+
         IntToStr(LEngth(PendingTXs))+' '+
         MyResumenHash+' '+
         IntToStr(MyConStatus)+' '+
         IntToStr(port);
End;

// Envia los mensajes salientes a todos los pares
Procedure SendMesjsSalientes();
Var
  Slot :integer = 1;
Begin
While OutgoingMsjs.Count > 0 do
   begin
   For Slot := 1 to MaxConecciones do
      begin
      if conexiones[Slot].tipo <> '' then PTC_SendLine(Slot,OutgoingMsjs[0]);
      end;
   if OutgoingMsjs.Count > 0 then OutgoingMsjs.Delete(0);
   end;
End;

// Envia las TXs pendientes al slot indicado
procedure PTC_SendPending(Slot:int64);
var
  contador : integer;
  Encab : string;
  Textline : String;
  TextOrder : String;
Begin
Encab := GetPTCEcn;
TextOrder := encab+'ORDER ';
if Length(PendingTXs) > 0 then
   begin
   for contador := 0 to Length(PendingTXs)-1 do
      begin
      Textline := GetStringFromOrder(PendingTXs[contador]);
      if (Pendingtxs[contador].OrderType='CUSTOM') then
         begin
         PTC_SendLine(slot,Encab+'$'+TextLine);
         end;
      if (Pendingtxs[contador].OrderType='TRFR') then
         begin
         if Pendingtxs[contador].TrxLine=1 then TextOrder:= TextOrder+IntToStr(Pendingtxs[contador].OrderLines)+' ';
         TextOrder := TextOrder+'$'+GetStringfromOrder(Pendingtxs[contador])+' ';
         if Pendingtxs[contador].OrderLines=Pendingtxs[contador].TrxLine then
            begin
            Setlength(TextOrder,length(TextOrder)-1);
            PTC_SendLine(slot,TextOrder);
            TextOrder := encab+'ORDER ';
            end;
         end;
      end;
   end;
End;

// Se recibe un mensaje con una solucion para el bloque
Procedure PTC_Newblock(Texto:String);
var
  TimeStamp       : string = '';
  NumeroBloque    : string = '';
  DireccionMinero : string = '';
  Solucion        : string = '';
  Proceder : boolean = true;
Begin
if MyConStatus < 3 then
   begin
   OutgoingMsjs.Add(Texto);
   Proceder := false;
   end;
if proceder then
begin // proceder 1
TimeStamp       := Parameter (Texto,5);
NumeroBloque    := Parameter (Texto,6);
DireccionMinero := Parameter (Texto,7);
Solucion        := Parameter (Texto,8);
solucion        := StringReplace(Solucion,'_',' ',[rfReplaceAll, rfIgnoreCase]);
// Se recibe una solucion del siguiente bloque
if ((StrToIntDef(NumeroBloque,-1) = LastBlockData.Number+1) and
     (VerifySolutionForBlock(lastblockdata.NxtBlkDiff,MyLastBlockHash,DireccionMinero,Solucion)))then
   begin
   consoleLines.Add(LangLine(21)+NumeroBloque); //Solution for block received and verified:
   CrearNuevoBloque(StrToInt(NumeroBloque),StrToInt64(TimeStamp),Miner_Target,DireccionMinero,Solucion);
   end
// se recibe una solucion distinta del ultimo bloque pero mas antigua
else if ( (StrToIntDef(NumeroBloque,-1) = LastBlockData.Number) and
   (StrToInt64(timestamp)<LastBlockData.TimeEnd) and
   (VerifySolutionForBlock(lastblockdata.Difficult,LastBlockData.TargetHash,DireccionMinero,Solucion)
   and (StrToInt64(timestamp)+15 > StrToInt64(UTCTime))) ) then
      begin
      UndoneLastBlock;
      CrearNuevoBloque(StrToInt(NumeroBloque),StrToInt64(TimeStamp),Miner_Target,DireccionMinero,Solucion);
      end
// solucion distinta del ultimo con el mismo timestamp se elige la mas corta
else if ( (StrToIntDef(NumeroBloque,-1) = LastBlockData.Number) and
   (StrToInt64(timestamp)=LastBlockData.TimeEnd) and
   (VerifySolutionForBlock(lastblockdata.Difficult,LastBlockData.TargetHash,DireccionMinero,Solucion) and
   (StrToInt64(timestamp)+15 > StrToInt64(UTCTime))) and
   (DireccionMinero<>LastBlockData.AccountMiner) and
   (Solucion<LastBlockData.Solution) ) then
      begin
      UndoneLastBlock;
      CrearNuevoBloque(StrToInt(NumeroBloque),StrToInt64(TimeStamp),Miner_Target,DireccionMinero,Solucion);
      end;
end; // proceder 1
End;

// Envia el archivo resumen
Procedure PTC_SendResumen(Slot:int64);
var
  AFileStream : TFileStream;
Begin
AFileStream := TFileStream.Create(ResumenFilename, fmOpenRead + fmShareDenyNone);
if conexiones[slot].tipo='CLI' then
   begin
   Conexiones[slot].context.Connection.IOHandler.WriteLn('RESUMENFILE');
   Conexiones[slot].context.connection.IOHandler.Write(AFileStream,0,true);
   end;
if conexiones[slot].tipo='SER' then
   begin
   CanalCliente[slot].IOHandler.WriteLn('RESUMENFILE');
   CanalCliente[slot].IOHandler.Write(AFileStream,0,true);
   end;
AFileStream.Free;
consolelines.Add(LangLine(91));//'Headers file sent'
End;

// Enviar blockes
Procedure PTC_SendBlocks(Slot:integer;TextLine:String);
var
  FirstBlock, LastBlock : integer;
  MyZipFile: TZipper;
  contador : integer;
  AFileStream : TFileStream;
Begin
FirstBlock := StrToIntDef(Parameter(textline,5),-1)+1;
LastBlock := FirstBlock + 99; if LastBlock>MyLastBlock then LastBlock := MyLastBlock;
ConsoleLines.Add(LangLine(92)+IntToStr(FirstBlock)+'->'+IntToStr(LastBlock)); //'Requested blocks interval: '
MyZipFile := TZipper.Create;
MyZipFile.FileName := BlockDirectory+'Blocks_'+IntToStr(FirstBlock)+'_'+IntToStr(LastBlock)+'.zip';
for contador := FirstBlock to LastBlock do
   begin
   MyZipFile.Entries.AddFileEntry(BlockDirectory+IntToStr(contador)+'.blk');
   end;
MyZipFile.ZipAllFiles;
AFileStream := TFileStream.Create(MyZipFile.FileName , fmOpenRead + fmShareDenyNone);
   try
   if conexiones[Slot].tipo='CLI' then
      begin
      Conexiones[Slot].context.Connection.IOHandler.WriteLn('BLOCKZIP');
      Conexiones[Slot].context.connection.IOHandler.Write(AFileStream,0,true);
      end;
   if conexiones[Slot].tipo='SER' then
      begin
      CanalCliente[Slot].IOHandler.WriteLn('BLOCKZIP');
      CanalCliente[Slot].IOHandler.Write(AFileStream,0,true);
      end;
   finally
   AFileStream.Free;
   end;
MyZipFile.Free;
deletefile(BlockDirectory+'Blocks_'+IntToStr(FirstBlock)+'_'+IntToStr(LastBlock)+'.zip');
ConsoleLines.Add(LangLine(93)+IntToStr(FirstBlock)+'->'+IntToStr(LastBlock)); //'Sent blocks interval: '
End;

Procedure INC_PTC_Custom(TextLine:String);
Begin
AddCriptoOp(4,TextLine,'');
StartCriptoThread();
End;

// Procesa una solicitud de customizacion
Procedure PTC_Custom(TextLine:String);
var
  OrderInfo : OrderData;
  Address : String = '';
  OpData : String = '';
  Proceder : boolean = true;
Begin
OrderInfo := Default(OrderData);
OrderInfo := GetOrderFromString(TextLine);
Address := GetAddressFromPublicKey(OrderInfo.Sender);
// La direccion no dispone de fondos
if GetAddressBalance(Address)-GetAddressPendingPays(Address) < Customizationfee then Proceder:=false;
if TranxAlreadyPending(OrderInfo.TrfrID ) then Proceder:=false;
if OrderInfo.TimeStamp < LastBlockData.TimeStart then Proceder:=false;
if TrxExistsInLastBlock(OrderInfo.TrfrID) then Proceder:=false;
if AddressAlreadyCustomized(Address) then Proceder:=false;
If AddressSumaryIndex(OrderInfo.Receiver) >=0 then Proceder:=false;
if not VerifySignedString('Customize this '+Address+' '+OrderInfo.Receiver,OrderInfo.Signature,OrderInfo.Sender ) then Proceder:=false;
if proceder then
   begin
   OpData := GetOpData(TextLine); // Eliminar el encabezado
   AddPendingTxs(OrderInfo);
   OutgoingMsjs.Add(GetPTCEcn+opdata);
   end;
End;

// Valida que una transferencia cumpla los requisitos
function ValidateTrfr(order:orderdata;Origen:String):Boolean;
Begin
Result := true;
if GetAddressBalance(Origen)-GetAddressPendingPays(Origen) < Order.AmmountFee+order.AmmountTrf then
   result:=false;
if TranxAlreadyPending(order.TrfrID ) then
   result:=false;
if Order.TimeStamp < LastBlockData.TimeStart then
   result:=false;
if TrxExistsInLastBlock(Order.TrfrID) then
   result:=false;
if not VerifySignedString(IntToStr(order.TimeStamp)+origen+order.Receiver+IntToStr(order.AmmountTrf)+
   IntToStr(order.AmmountFee)+IntToStr(order.TrxLine),
   Order.Signature,Order.Sender ) then
   result:=false;
End;

Procedure INC_PTC_Order(TextLine:String);
Begin
AddCriptoOp(5,TextLine,'');
StartCriptoThread();
End;

Procedure PTC_Order(TextLine:String);
var
  NumTransfers : integer;
  TrxArray : Array of orderdata;
  SenderTrx : array of string;
  cont : integer;
  Textbak : string;
  SendersString : String = '';
  TodoValido : boolean = true;
  Proceder : boolean = true;
Begin
NumTransfers := StrToInt(Parameter(TextLine,5));
Textbak := GetOpData(TextLine);
SetLength(TrxArray,0);SetLength(SenderTrx,0);
for cont := 0 to NumTransfers-1 do
   begin
   SetLength(TrxArray,length(TrxArray)+1);SetLength(SenderTrx,length(SenderTrx)+1);
   TrxArray[cont] := default (orderdata);
   TrxArray[cont] := GetOrderFromString(Textbak);
   SenderTrx[cont] := GetAddressFromPublicKey(TrxArray[cont].Sender);
   if pos(SendersString,SenderTrx[cont]) > 0 then
      begin
      consolelines.Add(LangLine(94)); //'Duplicate sender in order'
      Proceder:=false; // hay una direccion de envio repetida
      end;
   SendersString := SendersString + SenderTrx[cont];
   Textbak := copy(textBak,2,length(textbak));
   Textbak := GetOpData(Textbak);
   end;
for cont := 0 to NumTransfers-1 do
   begin
   if not ValidateTrfr(TrxArray[cont],SenderTrx[cont]) then
      begin
      TodoValido := false;
      end;
   end;
if not todovalido then Proceder := false;
if proceder then
   begin
   Textbak := GetOpData(TextLine);
   Textbak := GetPTCEcn+'ORDER '+IntToStr(NumTransfers)+' '+Textbak;
   for cont := 0 to NumTransfers-1 do
      AddPendingTxs(TrxArray[cont]);
   OutgoingMsjs.Add(Textbak);
   U_DirPanel := true;
   end;
End;

END. // END UNIT

