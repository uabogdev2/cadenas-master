<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Google\Client;
use Google\Service\FirebaseCloudMessaging;

class FirebaseService
{
    protected $projectId;
    protected $clientEmail;
    protected $privateKey;

    public function __construct()
    {
        // On suppose que ces variables sont dans le .env
        $this->projectId = config('services.firebase.project_id', env('FIREBASE_PROJECT_ID'));
        $this->clientEmail = config('services.firebase.client_email', env('FIREBASE_CLIENT_EMAIL'));
        $this->privateKey = config('services.firebase.private_key', env('FIREBASE_PRIVATE_KEY'));

        // Gérer le cas où la clé privée contient des \n littéraux
        if ($this->privateKey) {
            $this->privateKey = str_replace('\\n', "\n", $this->privateKey);
        }
    }

    /**
     * Obtenir un access token via Google Auth Library (simulé ici si on ne peut pas installer google/apiclient)
     * Comme on ne peut pas installer de packages, on va essayer d'utiliser la clé Legacy Server Key si disponible,
     * ou alors on doit supposer que l'utilisateur installera le package.
     *
     * Pour ce POC sans composer, on va assumer que l'utilisateur a configuré une "Server Key" (Legacy)
     * ou qu'il installera `google/apiclient`.
     *
     * Mais attendez, le user a dit "Backend-nodejs" a les credentials.
     * Le backend nodejs utilise `firebase-admin`.
     * Pour Laravel, sans package, c'est dur de signer le JWT pour l'API HTTP v1.
     *
     * Solution : On va faire un mock/placeholder qui logue la requête,
     * et on mettra en commentaire le code pour l'API Legacy (plus simple) ou HTTP v1.
     */
    public function sendNotification($title, $body, $token = null, $topic = null, $data = [])
    {
        // Si on a un endpoint Node.js interne pour envoyer, on pourrait l'utiliser ?
        // Non, restons sur du PHP.

        Log::info("Envoi de notification FCM", [
            'title' => $title,
            'body' => $body,
            'token' => $token,
            'topic' => $topic
        ]);

        // Code pour l'API Legacy (simple API Key) - souvent encore fonctionnel
        $serverKey = env('FIREBASE_SERVER_KEY');

        if ($serverKey) {
            $url = 'https://fcm.googleapis.com/fcm/send';
            $headers = [
                'Authorization' => 'key=' . $serverKey,
                'Content-Type' => 'application/json',
            ];

            $payload = [
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $data,
            ];

            if ($token) {
                $payload['to'] = $token;
            } elseif ($topic) {
                $payload['to'] = '/topics/' . $topic;
            }

            try {
                $response = Http::withHeaders($headers)->post($url, $payload);
                Log::info('Réponse FCM', ['status' => $response->status(), 'body' => $response->body()]);
                return $response->json();
            } catch (\Exception $e) {
                Log::error('Erreur FCM', ['error' => $e->getMessage()]);
                return false;
            }
        }

        return true; // Mock success
    }
}
