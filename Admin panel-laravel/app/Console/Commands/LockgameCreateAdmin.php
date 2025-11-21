<?php

namespace App\Console\Commands;

use App\Models\Admin;
use App\Models\User;
use Illuminate\Console\Command;

class LockgameCreateAdmin extends Command
{
    protected $signature = 'lockgame:create-admin {uid : ID de l\'utilisateur} 
        {--manage-users}
        {--manage-levels}
        {--manage-battles}
        {--view-stats}
        {--manage-admins}
        {--all : Active toutes les permissions}
        {--password= : Mot de passe explicite (sinon généré aléatoirement)}';

    protected $description = 'Crée ou met à jour un administrateur Lockgame avec les permissions souhaitées.';

    public function handle(): int
    {
        $uid = (string) $this->argument('uid');
        $user = User::query()->find($uid);

        if (! $user) {
            $this->error("Utilisateur {$uid} introuvable.");

            return self::FAILURE;
        }

        $permissions = $this->buildPermissions();

        $admin = Admin::query()->firstOrNew(['userId' => $uid]);
        $admin->isAdmin = true;
        $admin->permissions = $permissions;

        $plainPassword = $this->determinePassword($admin);

        $admin->save();

        $this->info("Admin {$user->displayName} ({$uid}) synchronisé.");

        if ($plainPassword) {
            $this->comment("Mot de passe provisoire: {$plainPassword}");
        }

        return self::SUCCESS;
    }

    protected function buildPermissions(): array
    {
        $all = (bool) $this->option('all');

        return [
            'manageUsers' => $all || (bool) $this->option('manage-users'),
            'manageLevels' => $all || (bool) $this->option('manage-levels'),
            'manageBattles' => $all || (bool) $this->option('manage-battles'),
            'viewStats' => $all || (bool) $this->option('view-stats'),
            'manageAdmins' => $all || (bool) $this->option('manage-admins'),
        ];
    }

    protected function determinePassword(Admin $admin): ?string
    {
        $explicit = $this->option('password');

        if ($explicit !== null) {
            $admin->password = $explicit;

            return $explicit;
        }

        if ($admin->exists) {
            return null;
        }

        $generated = bin2hex(random_bytes(10));
        $admin->password = $generated;

        return $generated;
    }
}

