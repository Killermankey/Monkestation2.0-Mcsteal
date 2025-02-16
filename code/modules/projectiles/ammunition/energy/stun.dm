/obj/item/ammo_casing/energy/electrode
	projectile_type = /obj/projectile/energy/electrode
	select_name = "stun"
	fire_sound = 'sound/weapons/taser.ogg'
	e_cost = 200
	harmful = FALSE

/obj/item/ammo_casing/energy/electrode/hos //monkestation edit
	e_cost = 300

/obj/item/ammo_casing/energy/electrode/spec
	e_cost = 100

/obj/item/ammo_casing/energy/electrode/gun
	fire_sound = 'sound/weapons/gun/pistol/shot.ogg'
	e_cost = 100

/obj/item/ammo_casing/energy/electrode/old
	e_cost = 1000

/obj/item/ammo_casing/energy/disabler
	projectile_type = /obj/projectile/beam/disabler
	select_name = "disable"
	e_cost = 50
	fire_sound = 'monkestation/sound/weapons/gun/energy/Laser2.ogg'
	harmful = FALSE

/obj/item/ammo_casing/energy/disabler/smg
	projectile_type = /obj/projectile/beam/disabler/weak
	e_cost = 25 //monkestation edit: half the damage but twice the ammo roughly
	fire_sound = 'sound/weapons/taser3.ogg'

/obj/item/ammo_casing/energy/disabler/hos
	e_cost = 60

/obj/item/ammo_casing/energy/disabler/smoothbore
	projectile_type = /obj/projectile/beam/disabler/smoothbore
	e_cost = 1000

/obj/item/ammo_casing/energy/disabler/smoothbore/prime
	projectile_type = /obj/projectile/beam/disabler/smoothbore/prime
	e_cost = 500
