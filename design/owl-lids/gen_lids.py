from PIL import Image, ImageFilter, ImageDraw
import numpy as np, sys
im=Image.open('x/SquealIcon/Icon.png').convert('RGB'); a=np.asarray(im).astype(float)
M=np.load('eyemasks.npy'); N=1024
lum=a.mean(2)
grow=lambda m,k: np.asarray(Image.fromarray((m*255).astype('uint8')).filter(ImageFilter.MaxFilter(k)))>0
cover=[grow(m,5) for m in M]                       # covers the eye's own soft edge
dil=[grow(m,9) for m in M]
soft=[np.asarray(Image.fromarray((c*255).astype('uint8')).filter(ImageFilter.GaussianBlur(1)))/255. for c in cover]
shade=(lum>95)&(lum<200)&(M[0]|M[1])
shadeA=np.asarray(Image.fromarray((shade*255).astype('uint8')).filter(ImageFilter.GaussianBlur(1)))/255.
lidc=[np.array([38,34,65.]), np.array([33,29,57.])]
DARK=np.array([10,0,38.])
yy,xx=np.mgrid[0:N,0:N]
def fill_dir(eye, vfun):
    out=np.zeros((N,N,3)); m=dil[eye]; ys,xs=np.where(m); todo=np.ones(len(ys),bool); res=np.zeros((len(ys),3))
    vx,vy=vfun(xs,ys)
    for k in range(1,800,2):
        if not todo.any(): break
        px=np.clip((xs+vx*k).round().astype(int),0,N-1); py=np.clip((ys+vy*k).round().astype(int),0,N-1)
        hit=todo & ~m[py,px]
        px2=np.clip((xs+vx*(k+4)).round().astype(int),0,N-1); py2=np.clip((ys+vy*(k+4)).round().astype(int),0,N-1)
        res[hit]=a[py2[hit],px2[hit]]; todo&=~hit
    res[todo]=lidc[eye]; out[ys,xs]=res; return out
const=lambda c:(lambda xs,ys:(np.full(len(xs),c[0]),np.full(len(xs),c[1])))
def lashline(e):
    m=M[e]; ys,xs=np.where(m); L=Image.new('L',(N,N),0); d=ImageDraw.Draw(L); pts=[]
    for x in range(xs.min()+8, xs.max()-6, 3):
        col=np.where(m[:,x])[0]
        if len(col): pts.append((x,col.max()-3))
    d.line(pts,fill=255,width=8,joint='curve')
    return np.asarray(L.filter(ImageFilter.GaussianBlur(1)))/255.*soft[e]
def compose(fills, lash=False, shadow=.62):
    img=a.copy()
    for e in (0,1):
        al=soft[e][...,None]; img=img*(1-al)+fills[e]*al
    if shadow: img=img*(1-shadeA[...,None]*(1-shadow))              # the brow's shadow, now on the lid
    if lash:
        for e in (0,1):
            la=lashline(e)[...,None]; img=img*(1-la)+DARK*la
    return img
def eyes(v): return [fill_dir(0,const(v)), fill_dir(1,const((-v[0],v[1])))]
flat=[np.zeros((N,N,3))+lidc[0], np.zeros((N,N,3))+lidc[1]]
s=np.array([-0.75,-0.66]); s/=np.linalg.norm(s)
def radial(e,c=(512,820)):
    return fill_dir(e,lambda xs,ys:((xs-c[0])/(np.hypot(xs-c[0],ys-c[1])+1e-6),(ys-c[1])/(np.hypot(xs-c[0],ys-c[1])+1e-6)))
def split():
    up=eyes((0,-1)); dn=eyes((0,1)); res=[]
    for e in (0,1):
        m=M[e]; top=np.zeros((N,N),bool)
        for x in range(N):
            col=np.where(m[:,x])[0]
            if len(col): top[:,x]=yy[:,x] < col.min()*.45+col.max()*.55
        res.append(np.where(top[...,None],up[e],dn[e]))
    return res
V=[
 ("Гладкое веко цвета брови, с тенью", compose(flat)),
 ("Гладкое веко + тёмная линия ресниц", compose(flat, lash=True)),
 ("Полосы сверху (бровь и тёмное) идут вниз через веко", compose(eyes((0,-1)))),
 ("Полосы тела поднимаются вверх через веко", compose(eyes((0,1)))),
 ("Полосы тела вверх + линия ресниц", compose(eyes((0,1)), lash=True)),
 ("Боковые перья тянутся вдоль разреза глаза", compose(eyes(tuple(s)))),
 ("Перья от переносицы тянутся наружу", compose(eyes(tuple(-s)))),
 ("Сверху бровь, снизу тело, шов-ресницы", compose(split(), lash=True)),
 ("Перья расходятся лучами от груди", compose([radial(0),radial(1)])),
 ("Лучи от груди + линия ресниц", compose([radial(0),radial(1)], lash=True)),
]
for i,(name,img) in enumerate(V,1):
    Image.fromarray(np.clip(img,0,255).astype('uint8')).crop((0,60,1024,820)).resize((640,475),Image.LANCZOS).save(f'/home/user/squeal/design/owl-lids/lid-{i:02d}.png',optimize=True)
Image.fromarray(a.astype('uint8')).crop((0,60,1024,820)).resize((640,475),Image.LANCZOS).save('/home/user/squeal/design/owl-lids/lid-00-open.png',optimize=True)
open('/home/user/squeal/design/owl-lids/names.txt','w').write('\n'.join(f'{i}. {n}' for i,(n,_) in enumerate(V,1)))
ims=[Image.open(f'/home/user/squeal/design/owl-lids/lid-{i:02d}.png').resize((400,297)) for i in range(1,11)]
W=Image.new('RGB',(406*5,303*2),'white')
for i,x in enumerate(ims): W.paste(x,((i%5)*406,(i//5)*303))
W.save('/tmp/claude-0/-home-user/29b5693c-7fbb-5340-b4b7-2ce5b9f6df24/scratchpad/lids10.png')
