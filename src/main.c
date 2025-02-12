#include <windows.h>
#include <GL/GL.h>
#include <GL/glu.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <iostream> 
#include <gdiplus.h>
#include <windowsx.h>
#include "res.h"
#include <string.h>
#include <tchar.h>
#include <shlwapi.h>
extern "C" void registerClass(const char* a,WNDPROC b,HINSTANCE c);
extern "C" HWND ConstructWindow(const char*,const char*,WNDPROC proc,int32_t widthNheight);
extern "C" HGLRC createContext(HWND hwnd,HDC& hdc,uint32_t flags);
extern "C" unsigned int createTexture(uint32_t wh,int ChFilter,int format,unsigned char* bytes);
extern "C" unsigned int createBoard();
extern "C" int map_value(int old_val,int old_range,int new_range);
extern "C" uint32_t prng(unsigned int start,unsigned int end);
extern "C" unsigned char* placeFigures();
extern "C" void renderTile(int x,int y,int figure,unsigned int atlas);
extern "C" unsigned char CoordsToCell(LPARAM,HWND);
extern "C" unsigned char* LoadFromResource(int name, int type);
extern "C" HCURSOR loadCur(int id);
//extern "C" uint32_t hash(const char*);

extern "C" unsigned char* loadPNG(int ID,unsigned int* w,unsigned int* h);
extern "C" INT_PTR PAWN_PROMOTION_DIALOG(HWND hDlg,UINT msg,WPARAM w,LPARAM l);

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
int WinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd );
void draw();

#define GL_BGR 0x80E0
#define GL_BGRA 0x80E1

HDC hdc;
char isActive = 0;
using namespace Gdiplus;

unsigned int background;
unsigned int pieces;
unsigned char* cells;
#define EMPTY		0

#define W_PAWN		1
#define W_KNIGHT	2
#define W_ROOK		3
#define W_BISHOP	4
#define W_QUEEN		5
#define W_KING		6

#define B_PAWN		7
#define B_KNIGHT	8
#define B_ROOK		9
#define B_BISHOP	10
#define B_QUEEN		11
#define B_KING		12


// function can load any picture fmt supported by gdiplus,but we need only .png for chess pieces
// so be carefull with using it on other fmts(change color channels in that case)
// PNG IS LOADED UPSIDE DOWN!
// DONT FORGET ABOUT IT
unsigned char* loadImageFromResource(int resourceID,unsigned int* width,unsigned int* height)
{
	using namespace Gdiplus::DllExports;
    ULONG_PTR token;
    Gdiplus::GdiplusStartupInput tmp;
    Gdiplus::GdiplusStartup(&token, &tmp, NULL);
    auto hres = FindResource(0, MAKEINTRESOURCE(resourceID), RT_RCDATA);
	auto stream =  SHCreateMemStream((BYTE*)LockResource(LoadResource(0, hres)), SizeofResource(0, hres));
	GpBitmap* bitmap;
	GdipCreateBitmapFromStream(stream,&bitmap);
	stream->Release();
	GdipGetImageWidth(bitmap,width);
	GdipGetImageHeight(bitmap,height);
	
	unsigned int rect[] = {0,0,*width,*height};
	BitmapData bitmapData;
	GdipBitmapLockBits(bitmap,(GpRect*)rect,ImageLockModeRead,PixelFormat32bppARGB,&bitmapData);
	size_t total = (*width) * (*height) * 4; // we are loading only .png image,so 4 channels
	unsigned char* data = (unsigned char*)malloc(total);
    memcpy(data,bitmapData.Scan0,total);
	GdipBitmapUnlockBits(bitmap,&bitmapData);
    Gdiplus::GdiplusShutdown(token);
    return data; 
}

int WinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd )
{ 
	MSG msg;
	registerClass("sample_class",WndProc,hInstance);
	HWND win = ConstructWindow("Chess","sample_class",WndProc, 500 << 16 | 500);
	
	unsigned int w,h;
	unsigned char* bytes = loadImageFromResource(ATLAS,&w,&h);
	pieces = createTexture(w << 16 | h,4 << 16| GL_NEAREST,GL_BGRA,bytes);
	free(bytes); 
	
	glEnable(GL_TEXTURE_2D);
	glEnable (GL_DEPTH_TEST);
	glDepthMask(GL_TRUE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	gluPerspective(90,1,1,100);
	
	glTranslatef(-24,-24,-16);
	
	if(win) isActive = 1;
	
	while(isActive)
	{
		GetMessageA( &msg, 0, 0, 0 );
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	return 0;
}

void draw()
{
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);	
	glBindTexture(GL_TEXTURE_2D,background);
	glBegin(GL_QUADS);
	
	glTexCoord2f(0,0);
	glVertex3i(-8,-8,-16);
	 
	glTexCoord2f(1,0);
	glVertex3i( 56, -8,-16);
	
	glTexCoord2f(1,1);
	glVertex3i( 56, 56,-16);
	
	glTexCoord2f(0,1);
	glVertex3i(-8,56,-16);
	
	glEnd();
	for(int i = 0;i<64;i++)
	{
		renderTile(i%8,i/8,cells[i],pieces);
	}
	glFlush();
	SwapBuffers(hdc);
}

HCURSOR defCur;
HCURSOR dragCur;
INT_PTR CALLBACK PROM_PAWN_DIALOG(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	static int target = 0;
    switch (message)
    {
    case WM_INITDIALOG:
		target = lParam;
        return TRUE;
    case WM_COMMAND:
		cells[target] += LOWORD(wParam);
    case WM_CLOSE:
        EndDialog(hDlg, LOWORD(wParam));
        break;
    }
    return DefWindowProc(hDlg, message, wParam, lParam);
}
extern "C" bool checkMove(unsigned char* array,char turn,int se,DLGPROC func);

bool makeMove(unsigned char* array,char turn,int se,DLGPROC func)
{
	int start = se >> 16;
    int end = se & 0xFFFF;
    if (start == end || !array[start]) return false; // cannot move empty cell or stay at the same one

    char color = turn & 0b10;
    char isBottomPlayer = turn & 0b01;
    if ((color && array[start] > 6) || (!color && array[start] < 7)) return false; // order of turns
	
	if( array[start] > 6 && array[end] > 6) return false;
    if (array[start] < 7 && array[start] > 0 && array[end] < 7 && array[end] > 0) return false; // friendly fire

    int eRow = end / 8;
    if (array[start] == B_PAWN || array[start] == W_PAWN) {
        if ((isBottomPlayer && eRow == 7) || (!isBottomPlayer && eRow == 0)) 
        {
            DialogBoxParamA(0, MAKEINTRESOURCE(PROMOTE_PAWN), 0, func, start);
        }
    }
    return true;
}
LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	HGLRC hg = 0;
	static unsigned char sCell = 0;
	static unsigned char eCell = 0;
	static unsigned char turn = 0b10;// leftmost bit 1 - white, 0 - black
	switch(message) 
	{  
	case WM_CREATE:
	{
		HANDLE hIcon = LoadImageA(GetModuleHandleA(0), MAKEINTRESOURCE(MAINICON), IMAGE_ICON, 0, 0, LR_DEFAULTSIZE);
		SendMessage(hWnd, WM_SETICON, ICON_SMALL, (LPARAM) hIcon); 
		SendMessage(hWnd, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
		hg = createContext(hWnd,hdc,PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER);
		defCur = loadCur(IDC_CUSTOM_HOLD);
		dragCur = loadCur(IDC_CUSTOM_DRAG);
		SendMessage(hWnd,WM_SETCURSOR,(WPARAM)hWnd,0);
		background = createBoard();
		cells = placeFigures();
		if(cells[0] < 7) turn ^= 0b01; // set rightmost bit if bottom player is white(for pawns)
		break;
	}
	case WM_SETCURSOR:
	{
		switch(lParam)
		{
			case 0:
			SetCursor(defCur);
			break;
			case 1:
			SetCursor(dragCur);
			break;
		};
		break;
	}
	case WM_KEYDOWN:
	{
		switch(wParam)
		{
			case 0x52: // R
			free(cells);
			cells = placeFigures();
			turn = 0b10;
			if(cells[0] < 7) turn ^= 0b01; // set rightmost bit if bottom player is white(for pawns)
			break;
		}
	}
	case WM_PAINT:
		draw();
		BeginPaint(hWnd,0);
		EndPaint(hWnd,0);
		break;
	case WM_SIZE:
		glViewport(0,0,LOWORD(lParam),HIWORD(lParam));
		break;
	case WM_CLOSE:
		DestroyWindow(hWnd);
		break;
	case WM_DESTROY:
		isActive = 0;
		wglMakeCurrent(0,0);
		if(hg) wglDeleteContext(hg);
		if(hdc) ReleaseDC(hWnd,hdc);
		
		glDeleteTextures(1,&background); 
		glDeleteTextures(1,&pieces); 
		
		PostQuitMessage(0);
		break;
		
	case WM_LBUTTONDOWN:
	{
		SendMessage(hWnd,WM_SETCURSOR,(WPARAM)hWnd,1);
		sCell = CoordsToCell(lParam,hWnd);
		break;
	}
	case WM_LBUTTONUP:
	{
		SendMessage(hWnd,WM_SETCURSOR,(WPARAM)hWnd,0);
		eCell = CoordsToCell(lParam,hWnd);
		
		if(checkMove(cells,turn,sCell << 16 | eCell,PROM_PAWN_DIALOG))
		{
			cells[eCell] = cells[sCell];
			cells[sCell] = EMPTY;
			turn ^= 0b11;
			RECT rect;
			if(GetClientRect (hWnd, &rect))
			{
			  glViewport(0,0,rect.right,rect.bottom);
			  draw();
			}
		}
		
		break;
	}
	default:
		return DefWindowProc(hWnd, message, wParam, lParam);
	}
	return 0;
}
