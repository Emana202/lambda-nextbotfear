local sanicenable = CreateLambdaConvar( "lambdaplayers_lambda_fearnextbots", 1, true, false, false, "If Lambda Players should run away from sanic type nextbots", 0, 1, { type = "Bool", name = "Fear Sanic Nextbots", category = "Lambda Server Settings" } )
local drgenable = CreateLambdaConvar( "lambdaplayers_lambda_feardrgnextbots", 0, true, false, false, "If Lambda Players should run away from DRGBase nextbots", 0, 1, { type = "Bool", name = "Fear DRGBase Nextbots", category = "Lambda Server Settings" } )
if ( CLIENT ) then return end

--

local ipairs = ipairs
local IsValid = IsValid
local CurTime = CurTime
local SimpleTimer = timer.Simple
local random = math.random
local ai_ignoreplayers = GetConVar( "ai_ignoreplayers" )
local GetConVar = GetConVar
local FindInSphere = ents.FindInSphere
local constraint_RemoveAll = constraint.RemoveAll
local DamageInfo = DamageInfo

local function OnLambdaInitialize( self )
    self.l_nextbotfearcooldown = ( CurTime() + 0.5 )
end

local function OnLambdaThink( self, wepent, isDead )
    if CurTime() < self.l_nextbotfearcooldown then return end
    self.l_nextbotfearcooldown = ( CurTime() + 0.5 )
    if isDead then return end

    local sanics = sanicenable:GetBool()
    local drgs = drgenable:GetBool()
    local nearNextbot = self:GetClosestEntity( nil, 2000, function( ent ) 
        return ( ( ent:IsNextBot() and ( sanics and ent.LastPathingInfraction or drgs and ent.IsDrGNextbot ) ) and self:CanTarget( ent ) and self:CanSee( ent ) )
    end )

    if !nearNextbot then return end
    self:RetreatFrom( nearNextbot )
end

hook.Add( "LambdaOnInitialize", "lambdanextbotfearmodule_init", OnLambdaInitialize )
hook.Add( "LambdaOnThink", "lambdanextbotfearmodule_think", OnLambdaThink )

--

local function IsValidTarget( self, ent )
    if !IsValid( ent ) then return false end
    if ent.IsLambdaPlayer then return ent:Alive() end
    if ent:IsPlayer() then return ( ent:Alive() and !ai_ignoreplayers:GetBool() ) end

    local class = ent:GetClass()
    return ( ent:IsNPC() and ent:Health() > 0 and class != self:GetClass() and !class:find( "bullseye" ) )
end

local function IsPointNearSpawn( point, distance )
    local spawnPoints = GAMEMODE.SpawnPoints
    if spawnPoints or #spawnPoints == 0 then return false end

    distance = ( distance * distance )
    for _, spawnPoint in ipairs( spawnPoints ) do
        if !IsValid( spawnPoint ) or point:DistToSqr( spawnPoint:GetPos() ) <= distance then continue end
        return true
    end

    return false
end

local function GetNearestTarget( self )
    local selfClass = self:GetClass()

    local maxAcquireDist = GetConVar( selfClass .. "_acquire_distance" )
    maxAcquireDist = ( maxAcquireDist and maxAcquireDist:GetInt() or 2500 )
    
    local maxAcquireDistSqr = ( maxAcquireDist * maxAcquireDist )
    local selfPos = self:GetPos()
    local closestEnt

    local spawnProtect = GetConVar( selfClass .. "_spawn_protect" )
    spawnProtect = ( spawnProtect and spawnProtect:GetBool() or true )

    for _, ent in ipairs( FindInSphere( selfPos, maxAcquireDist ) ) do
        if !self:IsValidTarget( ent ) then continue end

        local entPos = ent:GetPos()
        if spawnProtect and ent:IsPlayer() and IsPointNearSpawn( entPos, 200 ) then continue end

        local distSqr = entPos:DistToSqr( selfPos )
        if distSqr >= maxAcquireDistSqr then continue end

        closestEnt = ent
        maxAcquireDistSqr = distSqr
    end

    return closestEnt
end

local function AttackNearbyTargets( self, radius )
    local selfClass = self:GetClass()

    local attackForce = GetConVar( selfClass .. "_attack_force" )
    attackForce = ( attackForce and attackForce:GetInt() or 800 )
    
    local smashProps = GetConVar( selfClass .. "_smash_props" )
    smashProps = ( smashProps and smashProps:GetBool() or true )

    local hit = false
    local hitSource = self:WorldSpaceCenter()

    for _, ent in ipairs( FindInSphere( hitSource, radius ) ) do
        if !self:IsValidTarget( ent ) then 
            if smashProps and ent:GetMoveType() == MOVETYPE_VPHYSICS and ( !ent:IsVehicle() or !IsValid( ent:GetDriver() ) ) then 
                local phys = ent:GetPhysicsObject()
                if IsValid( phys ) then
                    constraint.RemoveAll( ent )

                    local mass = phys:GetMass()
                    if mass >= 5 then ent:EmitSound( phys:GetMaterial() .. ".ImpactHard", 350, 120 ) end

                    local hitDirection = ( ent:WorldSpaceCenter() - hitSource ):GetNormalized()
                    local hitOffset = ent:NearestPoint( hitSource )
                    for i = 0, ( ent:GetPhysicsObjectCount() - 1 ) do
                        phys = ent:GetPhysicsObjectNum( i )
                        if !IsValid( phys ) then continue end
                        
                        phys:EnableMotion(true)
                        phys:ApplyForceOffset( hitDirection * ( attackForce * mass ), hitOffset )
                    end
                end
                ent:TakeDamage( 25, self, self )
            end
            
            continue 
        end

        if ent:IsPlayer() and IsValid( ent:GetVehicle() ) then
            local vehicle = ent:GetVehicle()

            local phys = vehicle:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
                local hitDirection = ( vehicle:WorldSpaceCenter() - hitSource ):GetNormalized()
                phys:ApplyForceOffset( hitDirection * ( attackForce * phys:GetMass() ), vehicle:NearestPoint(hitSource) )
            end

            vehicle:TakeDamage( math.huge, self, self )
            vehicle:EmitSound( "physics/metal/metal_sheet_impact_hard" .. random( 6, 8 ) .. ".wav", 350, 120 )
        else
            ent:EmitSound( "physics/body/body_medium_impact_hard" .. random( 6 ) .. ".wav", 350, 120 )
        end

        local hitDirection = ( ent:GetPos() - hitSource ):GetNormalized()
        local hitForce = ( hitDirection * attackForce + vector_up * 500 )
        ent:SetVelocity( hitForce )

        local oldHealth = ent:Health()

        local dmginfo = DamageInfo()
        dmginfo:SetAttacker( self )
        dmginfo:SetInflictor( self )
        dmginfo:SetDamage( math.huge )
        dmginfo:SetDamagePosition( hitSource )
        dmginfo:SetDamageForce( hitForce * 100 )

        ent:TakeDamageInfo( dmginfo )
        if !hit then hit = ( ent:Health() < oldHealth )  end
    end

    return hit
end

--

local function OnEntityCreated( ent )
    SimpleTimer( 0, function()
        if !IsValid( ent ) or !ent.LastPathingInfraction or !ent:IsNextBot() then return end
        ent.GetNearestTarget = GetNearestTarget
        ent.IsValidTarget = IsValidTarget
        ent.AttackNearbyTargets = AttackNearbyTargets
    end )
end

hook.Add( "OnEntityCreated", "lambdanextbotfearmodule_entitycreate", OnEntityCreated )