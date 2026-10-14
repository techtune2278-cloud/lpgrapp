import {reminderHandler} from '@/lib/notifications/server';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(request:Request){return reminderHandler(request)}
