import json,sys
def do(a="none",k=""): return {"act":a,"key":k}
def btn(n,**kw):
    b={"n":n}
    for f in ["click","dbl","hold","up","down","left","right"]: b[f]=kw.get(f,do())
    return b
sc=lambda c: do("shortcut","ctrl+opt+shift+"+c)
def prof(rev,zoom,btns): return {"smooth":False,"reverse":rev,"speed":1,"smoothness":0.12,"accel":False,"modifiers":True,"cmdZoom":zoom,"buttons":btns}
b3=[btn(3,click=sc("c"),dbl=sc("d"),hold=sc("h"))]
front=sys.argv[1]; mode=sys.argv[2]
cfg={"profile":prof(False,True,b3),"apps":[]}
if mode=="app": cfg["apps"]=[{"id":front,"name":"x","profile":prof(True,True,b3)}]
print(json.dumps(cfg))
