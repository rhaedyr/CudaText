(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit formkeys;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel,
  StdCtrls, Menus, ExtCtrls, IniFiles,
  LclType, LclProc, LazUTF8, LazFileUtils,
  ATSynEdit_Keymap,
  proc_globdata,
  proc_msg;

type
  { TfmKeys }

  TfmKeys = class(TForm)
    bAdd1: TButton;
    bAdd2: TButton;
    bClear1: TButton;
    bClear2: TButton;
    chkForLexer: TCheckBox;
    LabelDupInfo: TLabel;
    labelKey1: TLabel;
    labelKey2: TLabel;
    panelInput: TPanel;
    panelBtn: TButtonPanel;
    panelPress: TPanel;
    procedure bAdd1Click(Sender: TObject);
    procedure bAdd2Click(Sender: TObject);
    procedure bClear1Click(Sender: TObject);
    procedure bClear2Click(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure HelpButtonClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    { private declarations }
    FKeyPressed: integer;
    procedure DoAddKey(var K: TATKeyArray);
    procedure DoClearKey(var K: TATKeyArray);
    procedure DoUpdate;
    function GetHotkey: integer;
  public
    { public declarations }
    LexerName: string;
    CommandCode: integer;
    Keys1, Keys2: TATKeyArray;
  end;

var
  fmKeys: TfmKeys;

procedure DoLocalize_FormKeys(F: TfmKeys);


implementation

{$R *.lfm}

procedure DoLocalize_FormKeys(F: TfmKeys);
const
  section = 'd_keys';
var
  ini: TIniFile;
  fn: string;
begin
  fn:= GetAppLangFilename;
  if not FileExists(fn) then exit;
  ini:= TIniFile.Create(fn);
  try
    with F do Caption:= ini.ReadString(section, '_', Caption);
    with F.panelBtn.OKButton do Caption:= msgButtonOk;
    with F.panelBtn.CancelButton do Caption:= msgButtonCancel;

    with F.bClear1 do Caption:= ini.ReadString(section, 'clr', Caption);
    with F.bAdd1 do Caption:= ini.ReadString(section, 'add', Caption);
    F.bClear2.Caption:= F.bClear1.Caption;
    F.bAdd2.Caption:= F.bAdd1.Caption;

    with F.panelPress do Caption:= ini.ReadString(section, 'wait', Caption);
    with F.chkForLexer do Caption:= ini.ReadString(section, 'lex', Caption);
  finally
    FreeAndNil(ini);
  end;
end;

{ TfmKeys }

procedure TfmKeys.FormShow(Sender: TObject);
begin
  UpdateFormOnTop(Self);

  //OK btn needs confirmtion
  panelBtn.OKButton.ModalResult:= mrNone;

  DoUpdate;
end;

procedure TfmKeys.HelpButtonClick(Sender: TObject);
begin
  ModalResult:= mrNo;
end;

procedure TfmKeys.OKButtonClick(Sender: TObject);
var
  Item: TATKeymapItem;
  SDesc: string;
  N: integer;
begin
  Item:= TATKeymapItem.Create;
  try
    Item.Command:= CommandCode;
    Item.Keys1:= Keys1;
    Item.Keys2:= Keys2;

    N:= AppKeymapCheckDuplicateForCommand(Item, LexerName, false);
    if N=0 then
    begin
      ModalResult:= mrOk;
      exit;
    end;

    N:= AppKeymap.IndexOf(N);
    if N>=0 then
      SDesc:= AppKeymap.Items[N].Name
    else
      SDesc:= '??';

    if MsgBox(
         Format(msgConfirmHotkeyBusy, [SDesc]),
         MB_OKCANCEL or MB_ICONWARNING) = ID_OK then
    begin
      AppKeymapCheckDuplicateForCommand(Item, LexerName, true);
      ModalResult:= mrOk;
    end;
  finally
    Item.Free;
  end;
end;

procedure TfmKeys.bClear1Click(Sender: TObject);
begin
  DoClearKey(Keys1);
  DoUpdate;
end;

procedure TfmKeys.bClear2Click(Sender: TObject);
begin
  DoClearKey(Keys2);
  DoUpdate;
end;

procedure TfmKeys.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
  );
begin
  if not panelPress.Visible then exit;

  if
    (key=VK_MENU) or
    (key=VK_LMENU) or
    (key=VK_RMENU) or
    (key=VK_CONTROL) or
    (key=VK_LCONTROL) or
    (key=VK_RCONTROL) or
    (key=VK_SHIFT) or
    (key=VK_LSHIFT) or
    (key=VK_RSHIFT) or
    (key=VK_LWIN) or
    (key=VK_RWIN) then
      begin key:= 0; exit end;

  FKeyPressed:= ShortCut(Key, Shift);
  key:= 0;
end;

procedure TfmKeys.DoClearKey(var K: TATKeyArray);
var
  i: integer;
begin
  for i:= 0 to High(K) do K[i]:= 0;
end;

procedure TfmKeys.bAdd1Click(Sender: TObject);
begin
  DoAddKey(Keys1);
  DoUpdate;
end;

procedure TfmKeys.bAdd2Click(Sender: TObject);
begin
  DoAddKey(Keys2);
  DoUpdate;
end;

procedure TfmKeys.DoAddKey(var K: TATKeyArray);
var
  newkey, index, i: integer;
begin
  newkey:= GetHotkey;
  if newkey=0 then exit;

  index:= -1;
  for i:= 0 to High(K) do
    if K[i]=0 then
      begin index:= i; break end;
  if index<0 then exit;

  K[index]:= newkey;
end;

function TfmKeys.GetHotkey: integer;
begin
  Result:= 0;

  panelPress.Align:= alClient;
  panelInput.Hide;
  panelBtn.Hide;
  panelPress.Show;

  FKeyPressed:= 0;
  repeat
    Application.ProcessMessages;
  until FKeyPressed<>0;
  Result:= FKeyPressed;

  panelPress.Hide;
  panelBtn.Show;
  panelInput.Show;
end;

procedure TfmKeys.DoUpdate;
var
  Item: TATKeymapItem;
  SDesc: string;
  N: integer;
begin
  labelKey1.caption:= '1) '+ KeyArrayToString(Keys1);
  labelKey2.caption:= '2) '+ KeyArrayToString(Keys2);

  bAdd1.Enabled:= KeyArrayLength(Keys1)<cMaxKeyCombo;
  bAdd2.Enabled:= KeyArrayLength(Keys2)<cMaxKeyCombo;

  if bAdd1.Enabled then
    ActiveControl:= bAdd1
  else
  if bClear1.Enabled then
    ActiveControl:= bClear1;

  //check dups
  Item:= TATKeymapItem.Create;
  try
    Item.Command:= CommandCode;
    Item.Keys1:= Keys1;
    Item.Keys2:= Keys2;

    N:= AppKeymapCheckDuplicateForCommand(Item, LexerName, false);
    if N>0 then
    begin
      N:= AppKeymap.IndexOf(N);
      if N>=0 then
        SDesc:= AppKeymap.Items[N].Name
      else
        SDesc:= '??';

      LabelDupInfo.Show;
      LabelDupInfo.Caption:= Format(msgStatusHotkeyBusy, [SDesc]);
    end
    else
      LabelDupInfo.Hide;
  finally
    Item.Free;
  end;
end;

end.

