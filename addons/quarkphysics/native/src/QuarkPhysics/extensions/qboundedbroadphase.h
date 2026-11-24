#ifndef QBOUNDEDBROADPHASE_H
#define QBOUNDEDBROADPHASE_H

#include "../qbroadphase.h"
#include "../qmesh.h"
#include <unordered_map>
#include <unordered_set>
#include <cstdint>
#include <cmath>

// Opt-in centroid/radius broad phase. Rebuild after each constraint pass so
// contact corrections cannot invalidate a cached centroid or grid membership.
class QBoundedBroadPhase : public QBroadPhase {
    struct Entry { QBody *body; QVector center; float radius; bool bounded; QAABB box; };
    std::unordered_map<QBody*, float> radii;
    float cellSize=128.0f;
public:
    bool CanPair(QBody *a,QBody *b) { return BodiesCanCollide(a,b); }
    int gridPairs=0, circleRejected=0, narrowCandidates=0, expandedBounds=0;
    QBoundedBroadPhase(vector<QBody*> &worldBodies):QBroadPhase(worldBodies){}
    void Clear() override { pairs.clear(); }
    void Insert(QBody *body) override {}
    void Remove(QBody *body) override { radii.erase(body); pairs.clear(); }
    void SetRadius(QBody *body,float radius) { radii[body]=radius; }
    void SetCellSize(float size) { cellSize=std::max(16.0f,size); }
    std::unordered_set<std::pair<QBody*,QBody*>,QBody::BodyPairHash,QBody::BodyPairEqual> &GetPairs() override {
        pairs.clear(); gridPairs=circleRejected=narrowCandidates=expandedBounds=0;
        std::vector<Entry> entries;
        std::unordered_map<uint64_t,std::vector<size_t>> cells;
        std::unordered_set<std::pair<QBody*,QBody*>,QBody::BodyPairHash,QBody::BodyPairEqual> visited;
        for(auto body:bodies) {
            if(!body->GetEnabled()) continue;
            auto box=body->GetAABB();
            Entry e{body,(box.GetMin()+box.GetMax())*0.5f,0.0f,false,box};
            auto configured=radii.find(body);
            if(configured!=radii.end()) {
                e.bounded=true; e.center=QVector::Zero(); int count=0;
                for(auto mesh:*body->GetMeshes()) for(int i=0;i<mesh->GetParticleCount();++i) {
                    e.center+=mesh->GetParticleAt(i)->GetGlobalPosition(); ++count;
                }
                if(count) e.center=e.center*(1.0f/count);
                e.radius=configured->second;
                float actual=0.0f;
                QVector low=e.center,high=e.center;
                bool first=true;
                for(auto mesh:*body->GetMeshes()) for(int i=0;i<mesh->GetParticleCount();++i) {
                    auto p=mesh->GetParticleAt(i);
                    auto point=p->GetGlobalPosition();
                    float skin=std::max(0.5f,p->GetRadius());
                    actual=std::max(actual,(point-e.center).Length()+skin);
                    if(first) {low=point-QVector(skin,skin); high=point+QVector(skin,skin); first=false;}
                    low.x=std::min(low.x,point.x-skin); low.y=std::min(low.y,point.y-skin);
                    high.x=std::max(high.x,point.x+skin); high.y=std::max(high.y,point.y+skin);
                }
                e.box=QAABB(low-QVector(0.01f,0.01f),high+QVector(0.01f,0.01f));
                if(actual>e.radius) {e.radius=actual; ++expandedBounds;}
                e.radius+=0.01f;
            }
            QVector low=e.bounded?e.center-QVector(e.radius,e.radius):box.GetMin();
            QVector high=e.bounded?e.center+QVector(e.radius,e.radius):box.GetMax();
            size_t index=entries.size(); entries.push_back(e);
            for(int x=int(std::floor(low.x/cellSize));x<=int(std::floor(high.x/cellSize));++x)
                for(int y=int(std::floor(low.y/cellSize));y<=int(std::floor(high.y/cellSize));++y) {
                    uint64_t key=(uint64_t(uint32_t(x))<<32)|uint32_t(y);
                    auto &cell=cells[key];
                    for(auto other:cell) {
                        auto &b=entries[other];
                        auto pair=std::less<QBody*>()(e.body,b.body)?std::make_pair(e.body,b.body):std::make_pair(b.body,e.body);
                        if(!visited.insert(pair).second || !BodiesCanCollide(e.body,b.body)) continue;
                        ++gridPairs;
                        if(e.bounded && b.bounded && (e.center-b.center).LengthSquared()>(e.radius+b.radius)*(e.radius+b.radius)) {
                            ++circleRejected; continue;
                        }
                        // Secondary live bounds include the native particle
                        // skin omitted by the engine's cached tight AABB.
                        if(!e.box.isCollidingWith(b.box)) continue;
                        pairs.insert(pair); ++narrowCandidates;
                    }
                    cell.push_back(index);
                }
        }
        return pairs;
    }
};
#endif
