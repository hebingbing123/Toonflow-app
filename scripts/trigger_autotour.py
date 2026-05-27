import asyncio
import json
import urllib.request
import sys
import os
import websockets

async def run_cdp():
    # 1. Get debugger URL
    try:
        # Create a new tab navigating to the app
        req = urllib.request.urlopen("http://127.0.0.1:9222/json/new?http://localhost:54165")
        target = json.loads(req.read().decode())
        ws_url = target.get("webSocketDebuggerUrl")
        target_id = target.get("id")
        print(f"Created target: {target_id}, ws: {ws_url}")
    except Exception as e:
        print(f"Error creating new tab: {e}")
        # Try to fallback to existing tabs
        try:
            req = urllib.request.urlopen("http://127.0.0.1:9222/json")
            targets = json.loads(req.read().decode())
            ws_url = None
            for t in targets:
                if t.get("type") == "page" and "localhost" in t.get("url", ""):
                    ws_url = t.get("webSocketDebuggerUrl")
                    target_id = t.get("id")
                    break
            if not ws_url:
                for t in targets:
                    if t.get("type") == "page":
                        ws_url = t.get("webSocketDebuggerUrl")
                        target_id = t.get("id")
                        break
            if not ws_url:
                print("No page target found")
                return
            print(f"Connecting to existing target: {target_id}, ws: {ws_url}")
        except Exception as ex:
            print(f"Error fetching targets: {ex}")
            return

    # 2. Connect to WebSocket
    async with websockets.connect(ws_url) as websocket:
        # Enable Page
        await websocket.send(json.dumps({
            "id": 1,
            "method": "Page.enable"
        }))
        res = await websocket.recv()
        print("Page enabled:", res[:100])

        # Navigate (if not already navigated)
        print("Navigating to http://localhost:54165...")
        await websocket.send(json.dumps({
            "id": 2,
            "method": "Page.navigate",
            "params": {"url": "http://localhost:54165"}
        }))
        res = await websocket.recv()
        print("Navigation response:", res[:100])

        # Wait 8 seconds for flutter app to fully load
        print("Waiting for page to initialize...")
        await asyncio.sleep(8)

        # JS to click "Explore Demo" or "体 验" / "体验" / "游客"
        click_explore_js = """
        (() => {
            const buttons = Array.from(document.querySelectorAll('button, [role="button"], a, p, span, div'));
            const exploreBtn = buttons.find(b => {
                const txt = b.textContent || '';
                return txt.includes('Explore Demo') || txt.includes('体 验') || txt.includes('体验') || txt.includes('游客');
            });
            if (exploreBtn) {
                exploreBtn.click();
                return 'Clicked Explore Demo/Guest';
            }
            return 'Explore Demo button not found';
        })()
        """
        
        print("Clicking Explore Demo...")
        await websocket.send(json.dumps({
            "id": 3,
            "method": "Runtime.evaluate",
            "params": {
                "expression": click_explore_js,
                "returnByValue": True
            }
        }))
        res = await websocket.recv()
        print("Explore click result:", res[:300])

        # Wait 3 seconds for the onboarding overlay to appear
        print("Waiting for overlay to load...")
        await asyncio.sleep(3)

        # JS to click "Auto tour" or "自动导览"
        click_autotour_js = """
        (() => {
            const buttons = Array.from(document.querySelectorAll('button, [role="button"], a, p, span, div'));
            const tourBtn = buttons.find(b => {
                const txt = b.textContent || '';
                return txt.includes('Auto tour') || txt.includes('自动导览') || txt.includes('自动播放');
            });
            if (tourBtn) {
                tourBtn.click();
                return 'Clicked Auto tour';
            }
            return 'Auto tour button not found';
        })()
        """
        
        print("Clicking Auto tour / 自动导览...")
        await websocket.send(json.dumps({
            "id": 4,
            "method": "Runtime.evaluate",
            "params": {
                "expression": click_autotour_js,
                "returnByValue": True
            }
        }))
        res = await websocket.recv()
        print("Auto tour click result:", res[:300])
        
        print("Autotour triggered! Keeping browser open for the user to watch.")
        # Do not close or exit immediately, just finish execution

if __name__ == "__main__":
    asyncio.run(run_cdp())
