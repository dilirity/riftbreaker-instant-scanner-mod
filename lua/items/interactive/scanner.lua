local item = require("lua/items/weapons/autofire_weapon.lua")

class 'scanner' ( item )

function scanner:__init()
	item.__init(self)
end

function scanner:OnInit()
	item.OnInit( self )
	
	self.maxScanTime = self.data:GetFloatOrDefault( "scanning_time", 10 )
	self.lastTarget = INVALID_ID
	self.effect 	= INVALID_ID
	self.scanningTime = 0.0
	self.lastItemEnt = nil
	self.poseType = ""
	self.lastItemType = ""
end

function scanner:OnEquipped()
	item.OnEquipped( self ) 
	EntityService:SetGraphicsUniform( self.item, "cDissolveAmount", 1 )
end

function scanner:OnUnequipped()
	item.OnUnequipped( self ) 
end

function scanner:OnActivate()
	item.OnActivate( self )
	self:OnExecuteScaning()
	QueueEvent("ShowScannableRequest", event_sink, true )	
	local ownerData = EntityService:GetDatabase( self.owner );
	if ( self.data:GetInt( "activated" ) == 0  ) then
		self.lastItemEnt = ItemService:GetEquippedItem( self.owner, "RIGHT_HAND" )
		QueueEvent("FadeEntityOutRequest", self.lastItemEnt, 0.5)
		QueueEvent("FadeEntityInRequest", self.item, 0.5)
		self.lastItemType = ownerData:GetStringOrDefault( "RIGHT_HAND_item_type", "" )
		self.poseType = ownerData:GetStringOrDefault( "RIGHT_HAND_pose_type", "" )
	end
	
	ownerData:SetString( "RIGHT_HAND_item_type", "range_weapon" )
end

function scanner:OnDeactivate( forced )
	QueueEvent("ShowScannableRequest", event_sink, false )
	if ( self.effect ~= INVALID_ID )  then
		EntityService:RemoveEntity( self.effect )
		self.effect = INVALID_ID
	end
	local ownerData = EntityService:GetDatabase( self.owner );
	if ownerData ~= nil then
		ownerData:SetString( "RIGHT_HAND_item_type", self.lastItemType )
		ownerData:SetString( "RIGHT_HAND_pose_type", self.poseType )
		ownerData:SetFloat( "RIGHT_HAND_use_speed", 0 );
	end

	if ( forced == false and  self.lastItemEnt ~= nil and EntityService:IsAlive( self.lastItemEnt ) ) then
		QueueEvent("FadeEntityInRequest", self.lastItemEnt, 0.5)
	end
	QueueEvent("FadeEntityOutRequest", self.item, 0.5)
	self.lastItemEnt = nil
	self.lastTarget = INVALID_ID
	return item.OnDeactivate( self )
end

function scanner:SpawnSpecifcEffect( currentTarget )
		local effect
		local size = EntityService:GetBoundsSize( currentTarget )
		
		--LogService:Log( tostring( size.x ) ) 
		if ( size.x <= 2.5 ) then
			effect = "effects/mech/scanner_small"
		elseif ( size.x <= 4.5 ) then
			effect = "effects/mech/scanner"		
		elseif ( size.x <= 9.5 ) then
			effect = "effects/mech/scanner_big"		
		else
			effect = "effects/mech/scanner_very_big"		
		end
	
		self.effect = EntityService:SpawnAndAttachEntity( effect, currentTarget )		
end


function scanner:OnExecuteScaning()
	self.ammoEnt = EntityService:GetChildByName( self.item, "##ammo##" )
	if ( self.ammoEnt == nil or self.ammoEnt == INVALID_ID ) then
		return
	end
	
	local laserBeamComponent = EntityService:GetComponent( self.ammoEnt, "LaserBeamComponent")
	if ( laserBeamComponent ) then
		local currentTarget = tonumber(laserBeamComponent:GetField( "last_target" ):GetValue())
		
		if ( self.lastTarget ~= INVALID_ID and self.lastTarget ~= currentTarget ) then
			EntityService:RemoveEntity( self.effect )
			QueueEvent( "EntityScanningEndEvent", self.lastTarget )
			self.effect = INVALID_ID
			self.lastTarget = INVALID_ID
			self.scanningTime = 0.0
			EntityService:ChangeMaterial( self.ammoEnt, "projectiles/bioscanner_idle")
		end
		
		if ( currentTarget ~= INVALID_ID ) then		
			local scannableComponent = EntityService:GetComponent( currentTarget, "ScannableComponent")
			if ( scannableComponent == nil ) then
				EntityService:ChangeMaterial( self.ammoEnt, "projectiles/bioscanner_idle")
				return
			end
			if ( self.effect == INVALID_ID ) then
				EntityService:ChangeMaterial( self.ammoEnt, "projectiles/bioscanner_active")
				self.scanningTime = 0.0
				self:SpawnSpecifcEffect( currentTarget )
				QueueEvent( "EntityScanningStartEvent", currentTarget )
			elseif ( currentTarget == self.lastTarget ) then
				self.scanningTime = 10
				self.factor =  self.scanningTime / self.maxScanTime
				EffectService:SetParticleEmmissionUniform( self.effect, self.factor )
				if ( self.scanningTime >= self.maxScanTime ) then
					ItemService:ScanEntity( currentTarget, self.owner )
					EntityService:RemoveComponent( currentTarget, "ScannableComponent" ) 
					EntityService:RemoveEntity( self.effect )
					EffectService:DestroyEffectsByGroup( currentTarget, "scannable" )
					QueueEvent( "EntityScanningEndEvent", self.lastTarget )
					EffectService:SpawnEffect( currentTarget, "effects/loot/harvest_underground_mushroom")
					self.effect = INVALID_ID
					currentTarget = INVALID_ID
					self.scanningTime = 0.0
				end
			end
		end
		
		self.lastTarget = currentTarget;
	end
end

function scanner:DissolveShow()
	-- must be empty!
end

return scanner
