local sanicenable = CreateLambdaConvar( "lambdaplayers_lambda_fearnextbots", 1, true, false, false, "If Lambda Players should run away from Sanic-based Nextbots? Note that some will require manual addition via a panel due to how they're coded", 0, 1, { type = "Bool", name = "Fear Sanic Nextbots", category = "Fear Module" } )
local drgenable = CreateLambdaConvar( "lambdaplayers_lambda_feardrgnextbots", 0, true, false, false, "If Lambda Players should run away from any DRGBase Nextbots", 0, 1, { type = "Bool", name = "Fear DRGBase Nextbots", category = "Fear Module" } )
local fearrange = CreateLambdaConvar( "lambdaplayers_lambda_fearrange", 2000, true, false, false, "How close should the nextbot be to be detectable by Lambda Players", 0, 10000, { type = "Slider", decimals = 0, name = "Fear Spot Distance", category = "Fear Module" } )
--

local ipairs = ipairs

if ( CLIENT ) then
    local SortedPairsByMemberValue = SortedPairsByMemberValue
    local CreateVGUI = vgui.Create
    local pairs = pairs
    local list_Get = list.Get
    local lower = string.lower
    local AddNotification = notification.AddLegacy
    local Material = Material
    local PlayClientSound = surface.PlaySound
    local npcNameBgColor = Color( 72, 72, 72 )

    local function OpenNPCFearListPanel( ply )
        if !ply:IsSuperAdmin() then
            AddNotification( "You must be a Super Admin in order to use this!", 1, 4 )
            PlayClientSound( "buttons/button10.wav" )
            return
        end

        local frame = LAMBDAPANELS:CreateFrame( "NPC Fear List Panel", 800, 500 )

        local npcSelectPanel = LAMBDAPANELS:CreateBasicPanel( frame, LEFT )
        npcSelectPanel:SetSize( 430, 500 )

        local scrollPanel = LAMBDAPANELS:CreateScrollPanel( npcSelectPanel, false, FILL )

        local npcIconLayout = CreateVGUI( "DIconLayout", scrollPanel )
        npcIconLayout:Dock( FILL )
        npcIconLayout:SetSpaceX( 5 )
        npcIconLayout:SetSpaceY( 5 )

        local npcListPanel = CreateVGUI( "DListView", frame )
        npcListPanel:SetSize( 350, 500 )
        npcListPanel:DockMargin( 10, 0, 0, 0 )
        npcListPanel:Dock( LEFT )
        npcListPanel:AddColumn( "NPC", 1 )

        local textEntry = LAMBDAPANELS:CreateTextEntry( npcListPanel, BOTTOM, "Enter NPC's class here if it's not on the list" )
        local npcList = list_Get( "NPC" )

        function textEntry:OnEnter( class )
            if !class or #class == 0 then return end

            class = lower( class )
            textEntry:SetText( "" )

            for _, line in ipairs( npcListPanel:GetLines() ) do
                if lower( line:GetColumnText( 2 ) ) != class then continue end
                PlayClientSound( "buttons/button11.wav" )
                AddNotification( "The class is already registered in the list!", 1, 4 )
                return
            end

            local prettyName = ( npcList[ class ] and npcList[ class ].Name or false )
            npcListPanel:AddLine( ( prettyName and prettyName .. " (" .. class .. ")" or class ), class )

            for _, panel in ipairs( npcIconLayout:GetChildren() ) do
                if panel:GetNPC() == class then panel:Remove() break end
            end

            PlayClientSound( "buttons/lightswitch2.wav" )
            LAMBDAFS:UpdateKeyValueFile( "lambdaplayers/npcstofear.json", { [ class ] = true }, "json" )
        end

        local function AddNPCPanel( class )
            for _, v in ipairs( npcIconLayout:GetChildren() ) do
                if v:GetNPC() == class then return end
            end

            local npcPanel = npcIconLayout:Add( "DPanel" )
            npcPanel:SetSize( 100, 120 )
            npcPanel:SetBackgroundColor( npcNameBgColor )

            local npcImg = CreateVGUI( "DImageButton", npcPanel )
            npcImg:SetSize( 100, 100 )
            npcImg:Dock( TOP )

            local iconMat = Material( "entities/" .. class .. ".png" )
            if iconMat:IsError() then iconMat = Material( "entities/" .. class .. ".jpg" ) end
            if iconMat:IsError() then iconMat = Material( "vgui/entities/" .. class ) end
            if !iconMat:IsError() then npcImg:SetMaterial( iconMat ) end

            local prettyName = ( npcList[ class ] and npcList[ class ].Name or false )
            local npcName = LAMBDAPANELS:CreateLabel( ( prettyName or class ), npcPanel, TOP )

            function npcImg:DoClick()
                npcListPanel:AddLine( ( prettyName and prettyName .. " (" .. class .. ")" or class ), class )
                npcPanel:Remove()

                PlayClientSound( "buttons/lightswitch2.wav" )
                LAMBDAFS:UpdateKeyValueFile( "lambdaplayers/npcstofear.json", { [ class ] = true }, "json" )
            end

            function npcPanel:GetNPC()
                return class
            end
        end

        for _, v in SortedPairsByMemberValue( npcList, "Category" ) do
            AddNPCPanel( v.Class )
        end

        function npcListPanel:OnRowRightClick( id, line )
            local class = line:GetColumnText( 2 )
            if npcList[ class ] then AddNPCPanel( class ) end
            npcListPanel:RemoveLine( id )

            PlayClientSound( "buttons/combine_button3.wav" )
            LAMBDAFS:RemoveVarFromKVFile( "lambdaplayers/npcstofear.json", class, "json" )
        end

        LAMBDAPANELS:RequestDataFromServer( "lambdaplayers/npcstofear.json", "json", function( data )
            if !data then return end

            for class, _ in pairs( data ) do
                local listData = npcList[ class ]
                local prettyName = ( listData and listData.Name or false )
                npcListPanel:AddLine( ( prettyName and prettyName .. " (" .. class .. ")" or class ), class )

                for _, panel in ipairs( npcIconLayout:GetChildren() ) do
                    if panel:GetNPC() == class then panel:Remove() break end
                end
            end
        end )
    end

    RegisterLambdaPanel( "NPC Fear List", "Opens a panel that allows you to add a specific NPC that Lambda Players will fear and run away from. YOU MUST UPDATE LAMBDA DATA AFTER ANY CHANGES! You must be a Super Admin to use this panel!", OpenNPCFearListPanel, "Fear Module" )
else
    local IsValid = IsValid
    local CurTime = CurTime
    local SimpleTimer = timer.Simple
    local random = math.random
    local ai_ignoreplayers = GetConVar( "ai_ignoreplayers" )
    local GetConVar = GetConVar
    local FindInSphere = ents.FindInSphere
    local constraint_RemoveAll = constraint.RemoveAll
    local DamageInfo = DamageInfo

    --

    if !file.Exists( "lambdaplayers/npcstofear.json", "DATA" ) then
        LambdaNPCsToFearFrom = {}
        LAMBDAFS:WriteFile( "lambdaplayers/npcstofear.json", LambdaNPCsToFearFrom, nil, "GAME", false )
    else
        LambdaNPCsToFearFrom = LAMBDAFS:ReadFile( "lambdaplayers/npcstofear.json", "json" )
    end

    hook.Add( "LambdaOnDataUpdate", "lambdanextbotfearmodule_updatedata", function()
        LambdaNPCsToFearFrom = LAMBDAFS:ReadFile( "lambdaplayers/npcstofear.json", "json" )
    end )

    --

    local function OnLambdaInitialize( self )
        self.l_nextbotfearcooldown = ( CurTime() + 0.5 )
    end

    local function OnLambdaThink( self, wepent, isDead )
        if isDead then return end
        if CurTime() < self.l_nextbotfearcooldown then return end
        self.l_nextbotfearcooldown = ( CurTime() + 0.5 )

        local sanics = sanicenable:GetBool()
        local drgs = drgenable:GetBool()
        local nearNextbot = self:GetClosestEntity( nil, fearrange:GetInt(), function( ent )
            if !LambdaNPCsToFearFrom[ ent:GetClass() ] and ( !ent:IsNextBot() or ( !ent.LastPathingInfraction or !sanics ) and ( !ent.IsDrGNextbot or !drgs ) ) then return false end
            return ( ( !self:IsValidTarget( ent ) or self:CanTarget( ent ) ) and self:CanSee( ent ) )
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
                        constraint_RemoveAll( ent )

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
end