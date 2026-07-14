/**
 * Página pública de Política de Privacidad de Rapi Team.
 * Necesaria para el requisito de Google Play y App Store: URL de privacidad
 * que responde 200 y contiene el texto legal correspondiente.
 */
export const metadata = {
  title: 'Política de Privacidad · Rapi Team',
  description: 'Política de privacidad de la aplicación Rapi Team.',
}

export default function PrivacyPage() {
  const styles: React.CSSProperties = {
    maxWidth: '840px',
    margin: '0 auto',
    padding: '48px 24px 96px',
    fontFamily: 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    color: '#111827',
    lineHeight: 1.6,
  }
  const h1: React.CSSProperties = { fontSize: '32px', fontWeight: 700, marginBottom: '8px' }
  const h2: React.CSSProperties = { fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }
  const muted: React.CSSProperties = { color: '#6B7280', fontSize: '14px' }

  return (
    <main style={styles}>
      <h1 style={h1}>Política de Privacidad — Rapi Team</h1>
      <p style={muted}>Última actualización: 9 de julio de 2026</p>

      <p>
        Rapi Team es una aplicación móvil de transporte que conecta pasajeros y
        conductores en el Perú. Esta política describe qué datos recopilamos,
        con qué finalidad y cómo los protegemos.
      </p>

      <h2 style={h2}>1. Datos que recopilamos</h2>
      <ul>
        <li><b>Datos de cuenta:</b> nombre, correo electrónico, número de teléfono, foto de perfil, tipo de usuario (pasajero, conductor, dual).</li>
        <li><b>Datos de identificación (conductor):</b> DNI, licencia de conducir, SOAT, tarjeta de propiedad y placa del vehículo — necesarios para la verificación regulatoria del servicio de transporte.</li>
        <li><b>Ubicación en tiempo real:</b> mientras usa la app se recopila su ubicación GPS para calcular rutas, encontrar conductores cercanos y mostrar el trayecto en curso.</li>
        <li><b>Datos de pago:</b> transacciones con MercadoPago (no almacenamos su tarjeta de crédito; MercadoPago procesa los pagos directamente).</li>
        <li><b>Datos de viaje:</b> historial de viajes realizados, calificaciones, mensajes de chat con la contraparte.</li>
        <li><b>Datos técnicos:</b> identificador de dispositivo, tipo de dispositivo, versión de sistema operativo, token de notificaciones push (FCM).</li>
      </ul>

      <h2 style={h2}>2. Cómo usamos los datos</h2>
      <ul>
        <li>Para prestar el servicio de solicitar y aceptar viajes.</li>
        <li>Para procesar pagos y liquidar comisiones al conductor.</li>
        <li>Para enviar notificaciones sobre el estado del viaje.</li>
        <li>Para verificar la identidad y documentación del conductor.</li>
        <li>Para responder emergencias y contactar a las personas de emergencia registradas por el usuario si activa el botón de pánico.</li>
        <li>Para mejorar la calidad del servicio mediante análisis agregado de uso.</li>
      </ul>

      <h2 style={h2}>3. Con quién compartimos los datos</h2>
      <p>
        No vendemos ni cedemos sus datos a terceros con fines comerciales.
        Los compartimos únicamente con:
      </p>
      <ul>
        <li>La contraparte del viaje (nombre, foto, calificación) — sólo mientras dure el viaje.</li>
        <li>Proveedores tecnológicos que operan bajo contrato de confidencialidad: MercadoPago (pagos), Twilio (SMS de verificación), Firebase Cloud Messaging (envío de notificaciones push).</li>
        <li>Autoridades competentes cuando lo exija la ley peruana o una orden judicial.</li>
      </ul>

      <h2 style={h2}>4. Retención y eliminación</h2>
      <p>
        Sus datos se conservan mientras su cuenta esté activa. Puede eliminar
        su cuenta desde <i>Configuración → Eliminar mi cuenta</i> dentro de la
        app; al hacerlo, sus datos personales se borran permanentemente en
        un plazo máximo de 30 días. Los registros de viajes y transacciones se
        conservan de forma anonimizada por 5 años por obligaciones tributarias
        (SUNAT).
      </p>

      <h2 style={h2}>5. Seguridad</h2>
      <p>
        Los datos viajan cifrados con TLS 1.3. Las contraseñas se almacenan con
        bcrypt. El acceso interno a la base de datos está restringido por VPN y
        firewall. Las claves privadas nunca están en el código cliente.
      </p>

      <h2 style={h2}>6. Derechos del titular (Ley N° 29733 — Perú)</h2>
      <p>
        Usted tiene derecho a acceder, rectificar, cancelar y oponerse al
        tratamiento de sus datos personales. Para ejercer estos derechos escriba
        a <a href="mailto:facturacion.rapiteam@gmail.com">facturacion.rapiteam@gmail.com</a>.
      </p>

      <h2 style={h2}>7. Menores de edad</h2>
      <p>
        Rapi Team no está dirigido a menores de 18 años. Si detectamos una
        cuenta creada por un menor de edad, la eliminaremos.
      </p>

      <h2 style={h2}>8. Cambios a esta política</h2>
      <p>
        Podemos actualizar esta política. Si el cambio es sustancial le
        notificaremos por correo o al iniciar sesión en la app. La versión
        vigente siempre está publicada en esta URL.
      </p>

      <h2 style={h2}>9. Contacto</h2>
      <p>
        <b>RAPI SOLUCIONES GENERALES SAC</b><br />
        RUC 20612945790 · Perú<br />
        Email: <a href="mailto:facturacion.rapiteam@gmail.com">facturacion.rapiteam@gmail.com</a>
      </p>
    </main>
  )
}
