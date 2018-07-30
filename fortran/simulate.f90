module input
   implicit none

   ! Input file / Parameters
   real,    parameter :: dt = 0.05/60.0 !time step (min)
   real,    parameter :: final_time = 0.5*60.0 !minutes
   integer, parameter :: NumTrials = floor(final_time / dt)
   real,    parameter :: c_bulk = 0.2 ! Concentration bulk substrate
   real,    parameter :: v_width = 17.0 !Voxel length
   real,    parameter :: diff_s = 40680.0, diff_q = 33300.0 !Diffusion subst./QSM
   integer, parameter :: v_size(3) = (/10,10,100/)
   integer, parameter :: v_count = v_size(1) * v_size(2) * v_size(3)
   real,    parameter :: Vmax = 46e-3 !Maximum substrate uptake
   real,    parameter :: Ks = 2.34e-3 ! Half-saturaton const (substrate uptake)
   real,    parameter :: Zqd = 8.3, Zqu = 1230.0 !QSM production 
   real,    parameter :: Kq = 10
   real,    parameter :: Ymax = 0.444 
   real,    parameter :: maintenance = 0.6e-3 
   real,    parameter :: avg_mass_cell = 420.0
   real,    parameter :: density_cell = 290.0
   real,    parameter :: max_vol_frac = 0.52
   real,    parameter :: Mmax = 14700.0
   integer, parameter :: Nmax = floor(density_cell * max_vol_frac * v_width**3 / Mmax) !Standard input: 50
   real,    parameter :: alpha = 1.33
   real,    parameter :: beta = 10
   real,    parameter :: gamma = 0.1
   real,    parameter :: eps_mass = avg_mass_cell
   real,    parameter :: Zed = 0, Zeu = 1e-3
   real,    parameter :: mu = 1e-3 !Transfer coefficient
end

program simulate
   ! Simulates time-steps
   ! TODO Check correct timesteps. Updating of values should
   !      always refer to timestep 2
   use input
   implicit none

   ! Functions
   real, external :: avg

   ! Variables
   real,    dimension(v_count)         :: prod_s, prod_q
   integer, dimension(v_count,2)       :: eps_count
   real,    dimension(v_count,2)       :: c_s, c_q, eps_amount, pressure
   real,    dimension(Nmax,v_count,2)  :: biomass,up

   ! Loops
   integer :: i, n ! Standard indexes for loop
   real :: start, finish, start_update, finish_update, r, timer(9)
   timer(:) = 0.0

   ! Initialize arrays
   c_s(:,:) = c_bulk
   c_q(:,:) = 0.0
   up(:,:,:) = 0.0
   biomass(:,:,:) = 0.0
   eps_count(:,:) = 0
   eps_amount(:,:) = 0.0
   pressure(:,:) = 0.0


   do i = 1, v_size(1)*v_size(2)
      call random_number(r)
      call biomass_append(i, 400.0 + r*400.0, 0.0, biomass, up)
      biomass(:,i,1) = biomass(:,i,2)
   end do

   !!! CODE
   print*,"CODE START"
   print*,"Number of steps:", NumTrials
   print*,

   call cpu_time(start)

   ! TODO Updates independent of neighbours (all except concentration)
   !      can be calculated outside voxel loop
   ! TODO Slow parts: 
   !  1 update_eps
   !  3 update_stochastics
   !  5 update_displacement
   !  7 update_production_q
   do n = 1,NumTrials
      if (mod(n,floor(NumTrials/100.0)) == 0) print*, floor((real(n)/real(NumTrials)*100.0))

      call cpu_time(start_update)
      do i = 1, v_count
         call update_eps(i, biomass, up, eps_amount, eps_count)
      enddo
      call cpu_time(finish_update)
      timer(1) = (finish_update - start_update) + timer(1)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_mass(i, c_s, biomass)
      enddo
      call cpu_time(finish_update)
      timer(2) = (finish_update - start_update) + timer(2)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_stochastics(i,c_q,biomass,up)
      enddo
      call cpu_time(finish_update)
      timer(3) = (finish_update - start_update) + timer(3)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_pressure(i, biomass, eps_count, pressure)
      enddo
      call cpu_time(finish_update)
      timer(4) = (finish_update - start_update) + timer(4)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_displacement(i, pressure, biomass, eps_count,up)
      enddo
      call cpu_time(finish_update)
      timer(5) = (finish_update - start_update) + timer(5)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_production_s(i, c_s, biomass, prod_s)
      enddo
      call cpu_time(finish_update)
      timer(6) = (finish_update - start_update) + timer(6)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_production_q(i, c_q, biomass, up, prod_q)
      enddo
      call cpu_time(finish_update)
      timer(7) = (finish_update - start_update) + timer(7)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_concentration(i, prod_s, diff_s, c_s) !Substrate
      enddo
      call cpu_time(finish_update)
      timer(8) = (finish_update - start_update) + timer(8)

      call cpu_time(start_update)
      do i = 1, v_count
         call update_concentration(i, prod_q, diff_q, c_q) !QSM
      enddo
      call cpu_time(finish_update)
      timer(9) = (finish_update - start_update) + timer(9)


      c_s(:,1) = c_s(:,2) ! Insert the newly calculated concentrations
      c_q(:,1) = c_q(:,2)
      biomass(:,:,1) = biomass(:,:,2)
      eps_count(:,1) = eps_count(:,2)
      eps_amount(:,1) = eps_amount(:,2)
      up(:,:,1) = up(:,:,2)
      pressure(:,1) = pressure(:,2)
   end do

   call cpu_time(finish)

   print*,"CPU time(s):", finish-start
   print*,"Model time(min):", final_time
   print*, timer
   print*,
   print*,"Top"   ,c_s(10000,1)  ,c_q(10000,1)  ,eps_amount(10000,1)
   print*,"Mid"   ,c_s(5000,1)   ,c_q(5000,1)   ,eps_amount(5000,1)
   print*,"Bot"   ,c_s(1,1)      ,c_q(1,1)      ,eps_amount(1,1)
   print*,"AVG"   ,avg(c_s(:,1)) ,avg(c_q(:,1)) ,avg(eps_amount(:,1))
   print*,"Bio"   ,biomass(:4,1,1)
   print*,"upp"   ,up(:4,1,1)
   call get_count_up(1,biomass,up,i)
   print*,"Up:"   ,i
   call get_count_down(1,biomass,up,i)
   print*,"Dow"   ,i
   call get_count_particles(biomass(:,1,1),eps_count(1,1),i)
   print*,"Par"   ,i

end program simulate



subroutine update_pressure(i, biomass, eps_count, pressure)
   ! If the number of particles is above max, pressure = 1
   use input
   implicit none

   integer, intent(in) :: i, eps_count(v_count,2)
   real, intent(in) :: biomass(Nmax,v_count,2)
   real, intent(out) :: pressure(v_count,2)
   integer :: count

   call get_count_particles(biomass(:,i,1), eps_count(i,1), count)

   if (count >= Nmax) then
      pressure(i,2) = real(Nmax)
   else 
      pressure(i,2) = real(count) / (real(Nmax) - real(count))
   end if

end

subroutine update_displacement(i, pressure, biomass, eps_count, up)
   ! Depends on neighbours
   ! Slowest function (~6x as slow)
   use input
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: pressure(v_count,2)
   integer, intent(out) :: eps_count(v_count,2)
   real, intent(out) :: biomass(Nmax,v_count,2), up(Nmax,v_count,2)

   integer :: j,k, j_list_neigh(6), count, count_neigh, chosen, rand_int, count_displaced
   real :: up_temp,mass,tot_pressure, rand, P(6) ! Cumulative probability
   logical :: eps_displaced


   call get_count_particles(biomass(:,i,1), eps_count(i,1), count)

   ! Calculate how many particles are displaced

   count_displaced = 0
   call get_index_neighbours(i, j_list_neigh)
   if (count < Nmax) then !Update transfer depending on neighbours
      do j =1,6
         k = j_list_neigh(j)
         if (k < 1) cycle
         call get_count_particles(biomass(:,k,1), eps_count(k,1), count_neigh)
         if (pressure(i,1) > pressure(k,1) .AND. count > count_neigh) then
            count_displaced = count_displaced + floor(mu * (pressure(i,1) - pressure(k,1)) *(count - count_neigh) )
         endif
      end do
   else if (count >= Nmax) then ! Irrelevant of neighbours
      count_displaced = count - Nmax
   end if

   if (count_displaced < 0) print*, "Error, particle_transfer<0", count_displaced


   ! If paritcles are displaced
   if (count_displaced > 0) then
      ! Calculate probability for each neighbour
      tot_pressure = 0
      do j =1,6
         k = j_list_neigh(j)
         if (k < 1) cycle
         if (pressure(i,1) > pressure(k,1)) then
            tot_pressure = tot_pressure + (pressure(i,1) - pressure(k,1))
         end if
      end do

      
      do j =1,6
         k = j_list_neigh(j)
         if (pressure(i,1) > pressure(k,1) .AND. k > 0) then
            P(j) = (pressure(i,1) - pressure(k,1)) / tot_pressure
         else
            P(j) = 0
         end if
   
         if (j > 1) then ! Cumulative sum
            P(j) = P(j-1) + P(j)
         end if
      end do

      if (all(P == 0.0)) then
         count_displaced = 0
         print*, "Voxel overloaded", i
         return
      endif

      ! Calculate which neighbour(index) and particle is chosen
      ! neighbour
      do while (count_displaced > 0)
         call random_number(rand)
         do j =1,6
            if ( rand < P(j) ) then
               chosen = j_list_neigh(j)
               exit
            endif
         enddo
   
         ! Choose particle type
         call random_number(rand)
         rand_int = 1 + floor(count * rand) ! 1 - count
         eps_displaced = (rand_int <= eps_count(i,1))
   
         ! Remove and Append particles to neighbour
         if (eps_displaced) then
            eps_count(i,2) = eps_count(i,2) - 1 
            eps_count(chosen,2) = eps_count(chosen,2) + 1
         else !biomass displaced
            call biomass_remove_random(i,biomass,mass,up,up_temp)
            call biomass_append(chosen,mass,up_temp,biomass,up)
         endif
         count_displaced = count_displaced - 1
      enddo
   endif
end

real function avg(arr)
   ! Calculates the avg value of an array of v_count values
   use input
   implicit none
   real, intent(in) :: arr(v_count)
   avg = sum(arr) / size(arr)
   return
end

subroutine update_eps(i, biomass, up, eps_amount, eps_count)
   ! Calculate new eps. Create particle if eps > eps_mass
   ! TODO Check total particle count (Pressure?)
   use input !v_count Nmax Zed Zeu eps_mass
   implicit none

   integer, intent(in) :: i
   real, dimension(Nmax, v_count,2), intent(in)  :: biomass, up
   real, dimension(v_count,2), intent(out) :: eps_amount
   integer, intent(out) :: eps_count(v_count,2)
   integer :: count_up, count_down

   call get_count_up(i,biomass,up,count_up)
   call get_count_down(i,biomass,up,count_down)

   eps_amount(i,2) = eps_amount(i,2) + Zed*count_down + Zeu*count_up

   if (eps_amount(i,2) >= eps_mass) then
      eps_amount(i,2) = eps_amount(i,2) - eps_mass
      eps_count(i,2) = eps_count(i,2) + 1

      if (eps_count(i,2) > Nmax) then
         print*, "EPS count too high", i, eps_count(i,2)
      end if
   end if
end

subroutine update_mass(i, c_s, biomass)
   use input !v_count Nmax Ymax, Ks, Vmax, m, dt
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: c_s(v_count, 2)
   real, intent(out) :: biomass(Nmax,v_count,2)

   biomass(:,i,2) = biomass(:,i,1) &
      + dt*Ymax* ( c_s(i,2)/(Ks + c_s(i,2) ) - maintenance)*biomass(:,i,1)
end

subroutine update_production_q(i, c_q, biomass, up, prod_q)
   ! Output the production of QSM in voxel i
   use input !v_count,Nmax, Kq, Zqd, Zqu
   implicit none

   integer, intent(in)  :: i
   real, intent(in)     :: c_q(v_count,2)
   real, intent(in), dimension(Nmax,v_count,2) :: biomass, up
   real, intent(out)    :: prod_q(v_count)
   integer :: count_up, count_down

   call get_count_up(i,biomass,up,count_up)
   call get_count_down(i,biomass,up,count_down)

   prod_q(i) = Zqd*count_down + Zqu*count_up * c_q(i,1)/(Kq + c_q(i,1) )
end

subroutine get_count_up(i,biomass,up,count_up)
   ! TODO Worth it?
   use input
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: biomass(Nmax,v_count,2), up(Nmax,v_count,2)
   integer, intent(out) :: count_up
   integer :: count,j
   real :: M=0 !Tot mass in voxel

   

   count_up = 0
   !do j=1,Nmax
   !   M = biomass(j,i,1)
   !   call mass2cell_count(M, count)
   !   count_up = count_up + nint(count * up(j,i,1))
   !enddo
end

subroutine get_count_down(i,biomass,up,count_down)
   ! TODO Worth it?
   use input
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: biomass(Nmax,v_count,2), up(Nmax,v_count,2)
   integer, intent(out) :: count_down
   integer :: count,j
   real :: M=0 !Tot mass in voxel

   M = sum(biomass(:,i,1))
   call mass2cell_count(M,count_down)
   !do j=1,Nmax
   !   M = biomass(j,i,1)
   !   call mass2cell_count(M, count)
   !   count_down = count_down + nint(count * (1-up(j,i,1)))
   !enddo
end

subroutine get_count_particles(biomass_particle,eps_count_particle, count)
   ! TODO Worth it?
   ! Particle count in voxel! Misused as count in particle
   ! Nonzero entries in biomass_particle are a particle
   use input
   implicit none

   integer, intent(in)  :: eps_count_particle
   real,    intent(in)  :: biomass_particle(Nmax)
   integer, intent(out) :: count

   call get_count_nonzero(biomass_particle, count)
   count = count + eps_count_particle
end

subroutine get_count_nonzero(arr, n)
   ! Counts 
   use input !Nmax
   implicit none

   real,    intent(in)  :: arr(Nmax)
   integer, intent(out) :: n
   integer :: j

   n = count(arr .NE. 0)
end

subroutine update_stochastics(i, c_q, biomass, up)
   !TODO error due to up(j,i,1), j is not correct
   use input !v_count, dt
   implicit none

   integer, intent(in)  :: i
   real,    intent(in)  :: c_q(v_count,2), biomass(Nmax,v_count,2)
   real,    intent(out) :: up(Nmax,v_count,2)
   real :: d2u, u2d, rand
   integer :: count_up, count_down, count_d2u, count_u2d,j

   call get_count_down(i,biomass,up,count_down)
   call get_count_up(i,biomass,up,count_up)
   call probability_down2up(i,c_q,d2u)
   call probability_up2down(i,c_q,u2d)

   ! Down -> Up
   count_d2u = 0
   do j=1,count_down
      call random_number(rand)
      if (rand < dt * d2u) then
         count_d2u = count_d2u + 1
      end if
   end do
   ! Up -> Down
   count_u2d = 0
   do j=1,count_up
      call random_number(rand)
      if (rand < dt * u2d) then
         count_u2d = count_u2d + 1
      end if
   end do

   if (count_up > 0) then
      up(j,i,2) = 0!up(j,i,2) + (count_d2u-count_u2d) * up(j,i,2) / real(count_up)
   else if (count_down > 0) then
      up(j,i,2) = 0!(count_d2u - count_u2d) / real(count_down)
   end if
end

subroutine probability_down2up(i, c_q, prob)
   ! Calculates probability down to up
   use input !v_count, alpha, gamma
   implicit none
   integer, intent(in) :: i
   real, intent(in) :: c_q(v_count,2)
   real, intent(out) :: prob

   prob = alpha*c_q(i,1) / (1 + gamma *c_q(i,1))
end

subroutine probability_up2down(i, c_q, prob)
   ! Calculates probability down to up
   use input !v_count, beta, gamma
   implicit none
   integer, intent(in) :: i
   real, intent(in) :: c_q(v_count,2)
   real, intent(out) :: prob

   prob = beta / (1 + gamma *c_q(i,1))
end

subroutine update_production_s(i, c_s, biomass, prod_s)
   ! Calculate the new production of substrate and QSM
   ! in voxel i
   use input !Vmax, Ks, Nmax
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: c_s(v_count,2), biomass(Nmax, v_count, 2)
   real, intent(out) :: prod_s(v_count)
   real :: M=0 ! Total mass
    
   M = sum(biomass(:,i,1))
   prod_s(i) = - Vmax* M * c_s(i,1) / (Ks + c_s(i,1))
end

subroutine update_concentration(i, prod, diff, c)
   ! Updates conentration (Forward Euler step)
   ! Input index, diffusion constant, voxel width, c before/after
   ! Output new concentration
   use input
   implicit none
   integer, intent(in) :: i
   real, dimension(v_count,2), intent(out) :: c
   real, intent(in) :: prod(v_count), diff
   integer :: j_list_neigh(6), j
   
   call get_index_neighbours(i, j_list_neigh)
   do j = 1,6 !For every neighbour
      if (.NOT. (j_list_neigh(j)  < 1 ) ) then
         c(i,2) = c(i,2) + dt * (c(j_list_neigh(j),1) - c(i,1)) *  diff/(v_width*v_width) + dt*prod(i)/(v_width**3)
      end if
   end do
end

subroutine biomass_remove_random(i, biomass, mass, up, up_temp)
   use input
   implicit none

   integer, intent(in) :: i
   real, intent(out) :: biomass(Nmax, v_count, 2), up(Nmax,v_count,2)
   real, intent(out) :: mass, up_temp
   real :: rand
   integer :: rand_int, count_nonzero, j, n

   call get_count_nonzero(biomass(:,i,2), count_nonzero)
   call random_number(rand)
   rand_int = 1 + floor(count_nonzero * rand)

   ! Only check nonzeo values. 'n' variable keeps count.
   n = 1
   do j=1,Nmax
      if (biomass(j,i,2) == 0.0) cycle

      if (rand_int == n) then
         mass = biomass(j,i,2)
         biomass(j,i,2) = 0.0

         up_temp = up(j,i,2)
         up(j,i,2) = 0.0
         exit
      else
         n = n + 1
      endif
   enddo

end

subroutine biomass_append(i, mass,up_temp,biomass,up)
   ! TODO check total particle count
   ! Append mass at first non-zero biomass
   use input !Nmax
   implicit none

   integer, intent(in) :: i
   real, intent(in) :: mass
   real, intent(out) :: biomass(Nmax,v_count,2), up(Nmax,v_count,2)
   integer :: j
   real :: up_temp

   do j = 1,Nmax
      if (biomass(j,i,2) == 0.0) then
         biomass(j,i,2) = mass
         up(j,i,2) = up_temp
         exit
      endif

      if (j == Nmax) print*, "Couldn't append!", biomass(:,i,2)
   enddo

end

subroutine index2xyz(i, pos)
   ! Input index i
   ! Returns x y z in pos list
   use input
   implicit none
   integer, intent(in) :: i
   integer :: pos(3)
   integer :: x, y, z

   x = mod(i-1, v_size(1))
   y = mod( (i-1)/v_size(1), v_size(2))
   z = (i-1)/(v_size(1) * v_size(2))

   pos = (/x, y, z/)
end

subroutine xyz2index(pos, i)
   ! Input xyz in pos list
   ! Returns integer
   use input
   implicit none
   integer, intent(in) :: pos(3)
   integer, intent(out) :: i
   integer :: x,y,z
   x = pos(1)
   y = pos(2)
   z = pos(3)

   i = x + y * v_size(1) + z * v_size(1) * v_size(2) + 1
   
   if ((i < 1) .OR. (i > v_size(1)*v_size(2)*v_size(3))) then
      print*, "Error, i<=0 or i > v_count",i,x,y,z
      i = 0
   end if
end

subroutine get_index_neighbours(i, i_list_neigh)
   ! Input index
   ! Return list of indexes to neighbours
   use input
   implicit none
   integer, intent(in):: i
   integer, intent(out) :: i_list_neigh(6)
   integer :: pos(3), npos(3)
   i_list_neigh = (/0,0,0,0,0,0/)

   call index2xyz(i,pos) 

   ! x +- 1 (Boundary condition)
   npos = pos + (/1,0,0/)
   call continuous_boundary_condition(npos(1), v_size(1))
   call xyz2index(npos, i_list_neigh(1))

   npos = pos - (/1,0,0/)
   call continuous_boundary_condition(npos(1), v_size(1))
   call xyz2index(npos, i_list_neigh(2))

   ! y +- 1
   npos = pos + (/0,1,0/)
   call continuous_boundary_condition(npos(2), v_size(2))
   call xyz2index(npos, i_list_neigh(3))

   npos = pos - (/0,1,0/)
   call continuous_boundary_condition(npos(2), v_size(2))
   call xyz2index(npos, i_list_neigh(4))

   ! z +- 1
   npos = pos + (/0,0,1/)
   if (.NOT. (npos(3) >= v_size(3))) then
      call xyz2index(npos, i_list_neigh(5))
   end if

   npos = pos - (/0,0,1/)
   if (.NOT. (npos(3) < 0)) then
      call xyz2index(npos, i_list_neigh(6))
   end if
end

subroutine continuous_boundary_condition(pos_q, v_size_q)
   ! Input position in one direction with voxel size,
   ! Returns new position according to CBC
   implicit none
   integer, intent(out)::pos_q
   integer, intent(in)::v_size_q

   if (pos_q < 0) then
      pos_q = v_size_q-1
   else if (pos_q >= v_size_q) then
      pos_q = 0
   end if
end

subroutine mass2cell_count(mass, count)
   use input
   implicit none

   real, intent(in):: mass
   integer, intent(out) :: count

   count = ceiling(mass/avg_mass_cell)
end
