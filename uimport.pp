unit uimport;

{$mode ObjFPC}{$H+}

interface

uses
  CheckLst,Classes,ComCtrls,cyEditFilename,ExtCtrls,StdCtrls,SysUtils,Forms,
  Controls,Graphics,Dialogs;

type
  TfImport = class(TForm)
    bRun:TButton;
    lvSync:TListView;
    pnAct:TPanel;
    procedure bRunClick(Sender:TObject);
    procedure FormCreate(Sender:TObject);
  private

  public

  end;

var
  fImport: TfImport;

implementation

{$R *.lfm}

procedure TfImport.bRunClick(Sender:TObject);
begin

end;

procedure TfImport.FormCreate(Sender:TObject);
begin

end;

end.

