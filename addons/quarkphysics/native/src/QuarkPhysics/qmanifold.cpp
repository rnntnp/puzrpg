
/************************************************************************************
 * MIT License
 *
 * Copyright (c) 2023 Eray Zesen
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * https://github.com/erayzesen/QuarkPhysics
 *
**************************************************************************************/

#include "qmanifold.h"
#include "qareabody.h"
#include "qbody.h"
#include "qrigidbody.h"
#include "qworld.h"
#include <iostream>
#include "qmesh.h"
#include "cmath"



QManifold::QManifold(QBody *bodyA, QBody *bodyB)
{
	if(bodyA<bodyB){
		this->bodyA=bodyA;
		this->bodyB=bodyB;
	}else{
		this->bodyA=bodyB;
		this->bodyB=bodyA;
	}

	restitution=min(bodyA->restitution,bodyB->restitution);
	//restitution=1.0f;

	//One time Computed Properties

	invMass=1/(bodyA->GetMass()+bodyB->GetMass());

	if(bodyA->CanGiveCollisionResponseTo(bodyB)==false || bodyB->CanGiveCollisionResponseTo(bodyA)==false ){
		isCollisionOneSide=true;
	}



}



QVector QManifold::GetRelativeVelocity(QParticle *contactParticle,vector<QParticle*> referenceParticles,QVector rRef, QVector rInc)
{

	QBody *bodyRef=referenceParticles[0]->GetOwnerMesh()->GetOwnerBody();
	QBody *bodyInc=contactParticle->GetOwnerMesh()->GetOwnerBody();

	QVector velRef=QVector::Zero();
	QVector velInc=QVector::Zero();
	float angVelRef=0;
	float angVelInc=0;

	if(bodyRef->GetSimulationModel()==QBody::RIGID_BODY ){
		//For RigidBodies
		angVelRef=bodyRef->GetRotation()-bodyRef->GetPreviousRotation();
		velRef=bodyRef->GetPosition()-bodyRef->GetPreviousPosition();
	}else{
		//For SoftBodies
		for(int i=0;i<referenceParticles.size();i++){
			auto p=referenceParticles[i];
			velRef+=p->GetGlobalPosition()-p->GetPreviousGlobalPosition();
		}
		velRef/=referenceParticles.size();

	}

	if( bodyInc->GetSimulationModel()==QBody::SimulationModels::RIGID_BODY  ){
		//For RigidBodies
		angVelInc=bodyInc->GetRotation()-bodyInc->GetPreviousRotation();
		velInc=bodyInc->GetPosition()-bodyInc->GetPreviousPosition();
	}else{
		//For SoftBodies
		velInc=contactParticle->GetGlobalPosition()-contactParticle->GetPreviousGlobalPosition();
	}


	return (velRef+angVelRef*-rRef.Perpendicular() )-( velInc + angVelInc*-rInc.Perpendicular() );
}





bool QManifold::BoundResponseWeights(QCollision::Contact *contact,float &referenceShare,float &incidentShare)
{
	auto inc=contact->particle;
	auto ref=contact->referenceParticles[0];
	auto incBody=inc->GetOwnerMesh()->GetOwnerBody();
	auto refBody=ref->GetOwnerMesh()->GetOwnerBody();
	if(!inc->IsMaterialBound() && !ref->IsMaterialBound()) return false;
	if(!inc->IsMaterialBound() && incBody->GetMode()!=QBody::STATIC) return false;
	if(!ref->IsMaterialBound() && refBody->GetMode()!=QBody::STATIC) return false;
	float incEffective=0.0f,refEffective=0.0f;
	if(inc->IsMaterialBound()) {
		for(float w:inc->materialWeights) incEffective+=w*w;
		incEffective*=inc->materialDrivers.size()/incBody->GetMass();
	}
	if(ref->IsMaterialBound()) {
		auto weights=ref->materialWeights;
		if(contact->referenceParticles.size()==2) {
			auto other=contact->referenceParticles[1];
			if(other->materialDrivers!=ref->materialDrivers) return false;
			auto edge=other->GetGlobalPosition()-ref->GetGlobalPosition();
			float t=max(0.0f,min(1.0f,(contact->position-ref->GetGlobalPosition()).Dot(edge)/max(edge.Dot(edge),0.000001f)));
			for(size_t i=0;i<weights.size();++i) weights[i]=weights[i]*(1.0f-t)+other->materialWeights[i]*t;
		}
		for(float w:weights) refEffective+=w*w;
		refEffective*=ref->materialDrivers.size()/refBody->GetMass();
	}
	float sum=max(incEffective+refEffective,0.000001f);
	referenceShare=refEffective/sum;
	incidentShare=incEffective/sum;
	return true;
}

void QManifold::Solve()
{

	bool betweenRigidbodies=false;
	bool betweenPressuredSoftbodies=false;
	if(bodyA->GetSimulationModel()==QBody::SimulationModels::RIGID_BODY && bodyB->GetSimulationModel()==QBody::SimulationModels::RIGID_BODY)
		betweenRigidbodies=true;

	//We apply half response to collisions between pressured soft bodies. 
	if(bodyA->GetSimulationModel()==QBody::SimulationModels::MASS_SPRING && bodyB->GetSimulationModel()==QBody::SimulationModels::MASS_SPRING ){
		QSoftBody *sbA=static_cast<QSoftBody*>(bodyA);
		QSoftBody *sbB=static_cast<QSoftBody*>(bodyB);
		if(sbA->GetAreaPreservingEnabled() && sbB->GetAreaPreservingEnabled())
			betweenPressuredSoftbodies=true;
	}

	


	// Shared material drivers move several boundary contacts at once. Keep a
	// linear contact margin and refresh its gap after every earlier correction.
	vector<float> boundMargins(contacts.size()),boundT(contacts.size());
	vector<bool> boundContacts(contacts.size(),false);
	for(size_t i=0;i<contacts.size();++i) {
		auto c=contacts[i];
		float refShare,incShare;
		if(!BoundResponseWeights(c,refShare,incShare)) continue;
		boundContacts[i]=true;
		auto ref=c->referenceParticles[0]->GetGlobalPosition();
		if(c->referenceParticles.size()==2) {
			auto edge=c->referenceParticles[1]->GetGlobalPosition()-ref;
			boundT[i]=max(0.0f,min(1.0f,(c->position-ref).Dot(edge)/max(edge.Dot(edge),0.000001f)));
			ref+=edge*boundT[i];
		}
		boundMargins[i]=(c->particle->GetGlobalPosition()-ref).Dot(c->normal)+c->penetration;
	}
	for(int i=0;i<contacts.size();i++){
		QCollision::Contact *contact=contacts[i];

		

		if(boundContacts[i]) {
			auto ref=contact->referenceParticles[0]->GetGlobalPosition();
			if(contact->referenceParticles.size()==2) ref+=(contact->referenceParticles[1]->GetGlobalPosition()-ref)*boundT[i];
			contact->position=ref;
			contact->penetration=max(0.0f,boundMargins[i]-(contact->particle->GetGlobalPosition()-ref).Dot(contact->normal));
		}else if(betweenRigidbodies){
			contact->penetration*=0.9f;
		}else if(betweenPressuredSoftbodies){
			contact->penetration*=0.5f;
		}

		contact->penetration=max(contact->penetration,0.0f);

		QVector responseForce=contact->normal*(contact->penetration);
		if(restitution>0.0f && !boundContacts[i])
			responseForce*=2.0f;

		if(betweenRigidbodies==true)
			responseForce/=contacts.size();



		bodyA->GetWorld()->gizmos.push_back( new QGizmoRect( QAABB(contact->position+QVector(-0.5f,-0.5f) ,contact->position+QVector(0.5f,0.5f) ) ));



		QBody *referenceBody=contact->referenceParticles[0]->GetOwnerMesh()->GetOwnerBody();
		QBody *incidentBody=contact->particle->GetOwnerMesh()->GetOwnerBody();


		
			

		



		QRigidBody *refRigidBody=nullptr;
		QRigidBody *incRigidBody=nullptr;

		if(referenceBody->GetBodyType()==QBody::BodyTypes::RIGID)
			refRigidBody=static_cast<QRigidBody*>(referenceBody);
		if(incidentBody->GetBodyType()==QBody::BodyTypes::RIGID)
			incRigidBody=static_cast<QRigidBody*>(incidentBody);

		QVector rRef=contact->position-referenceBody->GetPosition();
		QVector rInc=contact->position-incidentBody->GetPosition();

		if(i==0){
			linearRelativeVelocity=GetRelativeVelocity(contact->particle,contact->referenceParticles,rRef,rInc);
		}







		bool cancelSolving=false;

		//Checking Area Bodies

		if(referenceBody->GetBodyType()==QBody::BodyTypes::AREA){
			QAreaBody *refAreaBody=static_cast<QAreaBody*>(referenceBody);
			refAreaBody->AddCollidedBody(incidentBody);
			cancelSolving=true;
		}
	
		if(incidentBody->GetBodyType()==QBody::BodyTypes::AREA){
			QAreaBody *incAreaBody=static_cast<QAreaBody*>(incidentBody);
			incAreaBody->AddCollidedBody(referenceBody);
			cancelSolving=true;
		}

		//Calling Events

		QBody::CollisionInfo colInfoRef(contact->position,incidentBody,-contact->normal,contact->penetration);
		bool collisionEnabledByRef=referenceBody->OnCollision(colInfoRef);
		if(referenceBody->CollisionEventListener!=nullptr){
			bool listenerResult=referenceBody->CollisionEventListener(referenceBody,colInfoRef);
			if(collisionEnabledByRef==true)
				collisionEnabledByRef=listenerResult;
		}



		QBody::CollisionInfo colInfoInc(contact->position,referenceBody,contact->normal,contact->penetration);
		bool collisionEnabledByInc=incidentBody->OnCollision(colInfoInc);
		if(incidentBody->CollisionEventListener!=nullptr){
			bool listenerResult=incidentBody->CollisionEventListener(incidentBody,colInfoInc);
			if(collisionEnabledByInc==true)
				collisionEnabledByInc=listenerResult;
		}

		
		//Exceptions of Returns of Events.

		if(collisionEnabledByRef==false || collisionEnabledByInc==false){
			cancelSolving=true;
		}


		if(cancelSolving==true)
			continue;


		//Exceptions of Disabled Particles
		if(contact->particle->GetEnabled()==false  )
			continue;

		for (size_t n=0;n<contact->referenceParticles.size();++n ){
			if (contact->referenceParticles[n]->GetEnabled()==false ){
				cancelSolving=true;
				break;
			}
				
		}

		if(cancelSolving==true)
			continue;



		

		

		//Exceptions of Lazy Particles
		bool incidentParticleIsLazy=false;
		bool referenceParticlesAreLazy=false;
		if (contact->particle->GetIsLazy() ){
			contact->particle->previousCollidedBodies.insert(referenceBody);
			incidentParticleIsLazy=true;
			isCollisionOneSide=true;
		}

		for (size_t n=0;n<contact->referenceParticles.size();++n ){
			if (contact->referenceParticles[n]->GetIsLazy() ){
				contact->referenceParticles[n]->previousCollidedBodies.insert(incidentBody);
				isCollisionOneSide=true;
				referenceParticlesAreLazy=true;
			}
		}

		if (contact->particle->GetIsLazy() ){
			if( contact->particle->oneTimeCollidedBodies.find(referenceBody)!=contact->particle->oneTimeCollidedBodies.end() ){
				continue;
			}
		}
		
		for (size_t n=0;n<contact->referenceParticles.size();++n ){
			if (contact->referenceParticles[n]->GetIsLazy() ){
				if( contact->referenceParticles[n]->oneTimeCollidedBodies.find(incidentBody)!=contact->referenceParticles[n]->oneTimeCollidedBodies.end()  )
					cancelSolving=true;
					break;
			}
				
		}

		if(cancelSolving==true)
			continue;

		



		//APPLYING FORCES TO BODIES
		QVector refResponseForce;
		QVector incResponseForce;


		refResponseForce=-responseForce;
		incResponseForce=responseForce;


		float boundRefShare,boundIncShare;
		if(BoundResponseWeights(contact,boundRefShare,boundIncShare)) {
			refResponseForce*=boundRefShare;
			incResponseForce*=boundIncShare;
		}else if(isCollisionOneSide==false){
			refResponseForce*=incidentBody->GetMass()*invMass;
			incResponseForce*=referenceBody->GetMass()*invMass;
		}

		if(incidentBody->CanGiveCollisionResponseTo(referenceBody) && incidentParticleIsLazy==false){
			contact->solved=true;
			if(refRigidBody!=nullptr){
				//For RigidBodies
				refRigidBody->ApplyForce(refResponseForce,rRef,true);
			}else{
				//For Softbodies
				if(contact->referenceParticles.size()==2){
					QParticle::ApplyForceToParticleSegment(contact->referenceParticles[0],contact->referenceParticles[1],refResponseForce,contact->position );
				}else{
					contact->referenceParticles[0]->ApplyForce(refResponseForce);
				}
			}
		}

		if(referenceBody->CanGiveCollisionResponseTo(incidentBody) && referenceParticlesAreLazy==false){
			contact->solved=true;
			if(incRigidBody!=nullptr){
				//For RigidBodies
				incRigidBody->ApplyForce(incResponseForce,rInc,true);
			}else{
				//For Softbodies
				contact->particle->ApplyForce(incResponseForce);
			}
		}

		if(incidentParticleIsLazy || referenceParticlesAreLazy)
			contact->solved=false;



	}




}

void QManifold::SolveFrictionAndVelocities()
{
	//Don't apply friction and velocity to kinematic and static body pairs.
	bool isBodyADynamic=bodyA->isKinematic==false && bodyA->mode!=QBody::STATIC;
	bool isBodyBDynamic=bodyB->isKinematic==false && bodyB->mode!=QBody::STATIC;
	if(!isBodyADynamic && !isBodyBDynamic)
		return;


	for(int i=0;i<contacts.size();i++){
		QCollision::Contact *contact=contacts[i];
		//Don't apply friction and velocity to not solved contacts
		if(contact->solved==false) continue;


		QBody *referenceBody=contact->referenceParticles[0]->GetOwnerMesh()->GetOwnerBody();
		QBody *incidentBody=contact->particle->GetOwnerMesh()->GetOwnerBody();


		QRigidBody *refRigidBody=nullptr;
		QRigidBody *incRigidBody=nullptr;

		if(referenceBody->GetBodyType()==QBody::BodyTypes::RIGID)
			refRigidBody=static_cast<QRigidBody*>(referenceBody);
		if(incidentBody->GetBodyType()==QBody::BodyTypes::RIGID)
			incRigidBody=static_cast<QRigidBody*>(incidentBody);

		QVector rRef=contact->position-referenceBody->GetPosition();
		QVector rInc=contact->position-incidentBody->GetPosition();


		//Velocity Correction
		QVector relVel;

		if(i==0 && restitution>0.0f){
			auto j=linearRelativeVelocity.Dot(contact->normal);//+contact->prevImpulseScalar;
			if(j>restitution*2.0f){
				relVel=GetRelativeVelocity(contact->particle,contact->referenceParticles,QVector::Zero(),QVector::Zero());
				QVector tangent=relVel-(relVel.Dot(contact->normal)*contact->normal );
				auto jn=(j*contact->normal)*restitution-tangent;


				auto refImpulse=-jn;
				auto incImpulse=jn;

				if(isCollisionOneSide==false){
					refImpulse*=incidentBody->GetMass()*invMass;
					incImpulse*=referenceBody->GetMass()*invMass;
				}


				if(refRigidBody!=nullptr){
					//For RigidBodies
					if(incidentBody->CanGiveCollisionResponseTo(referenceBody) && referenceBody->isKinematic==false){
						refRigidBody->SetPreviousPosition(referenceBody->GetPosition()-refImpulse);
					}
				}else{
					//For Softbodies
				}

				if(incRigidBody!=nullptr){
					//For RigidBodies
					if(referenceBody->CanGiveCollisionResponseTo(incidentBody) && incidentBody->isKinematic==false){
						incRigidBody->SetPreviousPosition(incidentBody->GetPosition()-incImpulse);
					}
				}else{
					//For Softbodies
				}

			}
		}

		//FRICTIONS


		relVel=GetRelativeVelocity(contact->particle,contact->referenceParticles,rRef,rInc);
		float boundRefShare,boundIncShare;
		bool bound=BoundResponseWeights(contact,boundRefShare,boundIncShare);
		float wallFriction=-1.0f;
		if(bound && referenceBody->GetMode()==QBody::STATIC) wallFriction=referenceBody->GetFriction();
		if(bound && incidentBody->GetMode()==QBody::STATIC) wallFriction=incidentBody->GetFriction();
		QVector frictionForce=QBody::ComputeFriction(incidentBody,referenceBody,contact->normal,contact->penetration,relVel,wallFriction);

		QVector refResponseForce;
		QVector incResponseForce;


		//APPLYING FRICTION FORCE TO BODIES

		refResponseForce=frictionForce;
		incResponseForce=-frictionForce;

		if(bound) {
			refResponseForce*=boundRefShare;
			incResponseForce*=boundIncShare;
		}else if(isCollisionOneSide==false){
			refResponseForce*=incidentBody->GetMass()*invMass;
			incResponseForce*=referenceBody->GetMass()*invMass;
		}


		if(bound) {
			// Friction changes velocity, not the already projected geometry.
			// Applying it to positions reintroduced lateral drift on flat walls.
			auto ref=contact->referenceParticles[0];
			if(ref->IsMaterialBound() && incidentBody->CanGiveCollisionResponseTo(referenceBody)) {
				auto weights=ref->materialWeights;
				if(contact->referenceParticles.size()==2) {
					auto other=contact->referenceParticles[1];
					auto edge=other->GetGlobalPosition()-ref->GetGlobalPosition();
					float t=max(0.0f,min(1.0f,(contact->position-ref->GetGlobalPosition()).Dot(edge)/max(edge.Dot(edge),0.000001f)));
					for(size_t k=0;k<weights.size();++k) weights[k]=weights[k]*(1.0f-t)+other->materialWeights[k]*t;
				}
				float denominator=0.0f;
				for(float w:weights) denominator+=w*w;
				for(size_t k=0;k<weights.size();++k) ref->materialDrivers[k]->AddPreviousGlobalPosition(-refResponseForce*(weights[k]/max(denominator,0.000001f)));
			}
			if(contact->particle->IsMaterialBound() && referenceBody->CanGiveCollisionResponseTo(incidentBody)) contact->particle->AddPreviousGlobalPosition(-incResponseForce);
			continue;
		}
		if(incidentBody->CanGiveCollisionResponseTo(referenceBody) && referenceBody->isKinematic!=true){
			if(refRigidBody!=nullptr){
				//For RigidBodies
				refRigidBody->ApplyForce(refResponseForce,rRef);

			}else{
				//For Softbodies
				if(contact->referenceParticles.size()==2){
					QParticle::ApplyForceToParticleSegment(contact->referenceParticles[0],contact->referenceParticles[1],refResponseForce,contact->particle->GetGlobalPosition());
				}else{
					contact->referenceParticles[0]->ApplyForce(refResponseForce);
				}
			}
		}

		if(referenceBody->CanGiveCollisionResponseTo(incidentBody) && incidentBody->isKinematic!=true){
			if(incRigidBody!=nullptr){
				//For RigidBodies
				incRigidBody->ApplyForce(incResponseForce,rInc);

			}else{
				//For Softbodies
				contact->particle->ApplyForce(incResponseForce);
			}
		}






	}

}





