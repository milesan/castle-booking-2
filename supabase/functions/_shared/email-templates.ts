// Castle-themed styles
export const styles = {
  container: 'font-family: Georgia, serif; max-width: 600px; margin: 0 auto; background: #1a1a1a; color: #d4af37;',
  heading: 'color: #d4af37; text-align: center; font-family: Georgia, serif;',
  card: 'background: linear-gradient(135deg, #2a2a2a 0%, #1a1a1a 100%); padding: 30px; border: 1px solid #3a3a3a; margin: 20px 0;',
  label: 'display: block; color: #8b7355; margin-bottom: 4px; font-size: 12px; text-transform: uppercase; letter-spacing: 1px;',
  value: 'font-size: 18px; color: #d4af37; font-family: Georgia, serif;',
  button: 'background: linear-gradient(135deg, #d4af37 0%, #b8941f 100%); color: #1a1a1a; padding: 12px 32px; text-decoration: none; display: inline-block; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;',
  footer: 'color: #8b7355; text-align: center; font-size: 14px; margin-top: 40px;'
};

interface BookingEmailData {
  accommodation: string;
  formattedCheckIn: string;
  formattedCheckOut: string;
  totalPrice: number;
  bookingDetailsUrl: string;
}

export function generateBookingConfirmationEmail({
  accommodation,
  formattedCheckIn,
  formattedCheckOut,
  totalPrice,
  bookingDetailsUrl
}: BookingEmailData): string {
  return `
    <div style="${styles.container}; padding: 40px 20px;">
      <h1 style="${styles.heading}; font-size: 32px; margin-bottom: 10px;">Booking Confirmed</h1>
      <p style="text-align: center; color: #8b7355; margin-bottom: 30px; font-style: italic;">The Castle awaits</p>
      
      <div style="${styles.card}">
        <div style="margin-bottom: 25px;">
          <span style="${styles.label}">Accommodation</span>
          <div style="${styles.value}">${accommodation}</div>
        </div>
        
        <table cellpadding="0" cellspacing="0" border="0" style="width: 100%; margin: 25px 0;">
          <tr>
            <td style="width: 50%; padding-right: 15px;">
              <span style="${styles.label}">Check-in</span>
              <div style="${styles.value}">${formattedCheckIn}</div>
            </td>
            <td style="width: 50%; padding-left: 15px; border-left: 1px solid #3a3a3a;">
              <span style="${styles.label}">Check-out</span>
              <div style="${styles.value}">${formattedCheckOut}</div>
            </td>
          </tr>
        </table>
        
        <div style="margin-top: 30px; border-top: 1px solid #3a3a3a; padding-top: 20px;">
          <span style="${styles.label}">Total Amount</span>
          <div style="font-size: 24px; color: #d4af37; font-weight: bold;">€${totalPrice}</div>
        </div>
      </div>

      <div style="text-align: center; margin: 40px 0;">
        <a href="${bookingDetailsUrl}" style="${styles.button}">
          View Booking
        </a>
      </div>
      
      <div style="${styles.footer}">
        <p>A confirmation has been sent to your registered email address</p>
      </div>
    </div>
  `;
} 